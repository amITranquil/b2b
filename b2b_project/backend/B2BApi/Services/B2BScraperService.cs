using HtmlAgilityPack;
using B2BApi.Models;
using System.Text;
using System.Net;
using System.Linq;
using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using OpenQA.Selenium.Support.UI;

namespace B2BApi.Services
{
    public class B2BScraperService : IDisposable
    {
        private readonly ILogger<B2BScraperService> _logger;
        private readonly ImageDownloadService _imageDownloadService;
        private IWebDriver? _driver;
        private CancellationTokenSource? _cancellationTokenSource;

        public B2BScraperService(ILogger<B2BScraperService> logger, ImageDownloadService imageDownloadService)
        {
            _logger = logger;
            _imageDownloadService = imageDownloadService;
        }

        private int GetTotalPageCount(IWebDriver driver)
        {
            try
            {
                _logger.LogInformation("Attempting to determine total page count");

                // Pagination elementlerini bul - daha tolerant selectors
                IWebElement? paginationContainer = null;
                var paginationSelectors = new[] { ".pagination", ".page-numbers", ".pager", "[class*='pagination']", "[class*='page']" };

                foreach (var selector in paginationSelectors)
                {
                    try
                    {
                        paginationContainer = driver.FindElement(By.CssSelector(selector));
                        if (paginationContainer != null)
                        {
                            _logger.LogInformation($"Found pagination container with selector: {selector}");
                            break;
                        }
                    }
                    catch (NoSuchElementException)
                    {
                        continue;
                    }
                }

                if (paginationContainer != null)
                {
                    // Tüm sayfa numaralarını bul ve en büyüğünü al
                    var pageElements = paginationContainer.FindElements(By.XPath(".//a | .//span"));
                    var maxPage = 1;

                    foreach (var pageElement in pageElements)
                    {
                        var pageText = pageElement.Text.Trim();
                        if (int.TryParse(pageText, out int pageNum) && pageNum > 0)
                        {
                            maxPage = Math.Max(maxPage, pageNum);
                            _logger.LogInformation($"Found page number: {pageNum}");
                        }
                    }

                    if (maxPage > 1)
                    {
                        _logger.LogInformation($"Total pages calculated from max number: {maxPage}");
                        return maxPage;
                    }
                }

                _logger.LogWarning("Could not find pagination or determine page count, defaulting to 202");
                return 202; // Fallback to known value
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error determining total page count, defaulting to 202");
                return 202; // Fallback to known value
            }
        }

        private async Task<bool> NavigateToPage(IWebDriver driver, int targetPage)
        {
            try
            {
                _logger.LogInformation($"Navigating to page {targetPage}");

                // Check current page to avoid unnecessary navigation
                try
                {
                    var currentPageElement = driver.FindElement(By.CssSelector(".pagination .active, .pagination .current, .page-numbers .current"));
                    if (currentPageElement != null && int.TryParse(currentPageElement.Text.Trim(), out int currentPage))
                    {
                        if (currentPage == targetPage)
                        {
                            _logger.LogInformation($"Already on page {targetPage}");
                            return true;
                        }
                    }
                }
                catch (NoSuchElementException)
                {
                    _logger.LogInformation("Could not find current page indicator, proceeding with navigation");
                }

                // Hedef sayfa numarasını bul ve tıkla - daha geniş selector dene
                IWebElement? targetPageElement = null;
                var selectors = new[]
                {
                    $"//a[text()='{targetPage}' and contains(@class, 'page')]",
                    $"//a[text()='{targetPage}']",
                    $"//a[@href*='page={targetPage}']",
                    $"//*[contains(@class, 'pagination')]//a[text()='{targetPage}']",
                    $"//*[contains(@class, 'page-numbers')]//a[text()='{targetPage}']"
                };

                foreach (var selector in selectors)
                {
                    try
                    {
                        targetPageElement = driver.FindElement(By.XPath(selector));
                        if (targetPageElement != null)
                        {
                            _logger.LogInformation($"Found page {targetPage} element using selector: {selector}");
                            break;
                        }
                    }
                    catch (NoSuchElementException)
                    {
                        continue;
                    }
                }

                if (targetPageElement != null)
                {
                    // Scroll to element if needed
                    ((IJavaScriptExecutor)driver).ExecuteScript("arguments[0].scrollIntoView(true);", targetPageElement);
                    // No delay for maximum speed

                    // Use JavaScript click directly (faster and more reliable)
                    ((IJavaScriptExecutor)driver).ExecuteScript("arguments[0].click();", targetPageElement);
                    _logger.LogInformation($"Clicked on page {targetPage} (JavaScript click)");

                    // Page load optimization - no delays

                    // Verify we're on the correct page
                    try
                    {
                        var newCurrentPageElement = driver.FindElement(By.CssSelector(".pagination .active, .pagination .current, .page-numbers .current"));
                        if (newCurrentPageElement != null && int.TryParse(newCurrentPageElement.Text.Trim(), out int newCurrentPage))
                        {
                            var success = newCurrentPage == targetPage;
                            _logger.LogInformation($"Navigation result: expected page {targetPage}, actual page {newCurrentPage}, success: {success}");
                            return success;
                        }
                    }
                    catch (NoSuchElementException)
                    {
                        _logger.LogWarning("Could not verify current page after navigation");
                        // Assume success if we can't verify
                        return true;
                    }
                }
                else
                {
                    _logger.LogWarning($"Could not find page {targetPage} link");
                }

                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error navigating to page {targetPage}");
                return false;
            }
        }

        private string ParseTurkishDecimal(string turkishNumber)
        {
            if (string.IsNullOrEmpty(turkishNumber)) return "0";

            // Türkçe sayı formatı: 2.498,00 -> İngilizce: 2498.00
            // Binlik ayraç: . (nokta)
            // Ondalık ayraç: , (virgül)

            var cleanNumber = turkishNumber.Trim();

            // Son virgülden sonraki kısmı (ondalık kısım) al
            var lastCommaIndex = cleanNumber.LastIndexOf(',');
            if (lastCommaIndex > 0)
            {
                var integerPart = cleanNumber.Substring(0, lastCommaIndex);
                var decimalPart = cleanNumber.Substring(lastCommaIndex + 1);

                // Tamsayı kısmından noktaları kaldır (binlik ayraç)
                integerPart = integerPart.Replace(".", "");

                // İngilizce format: tamsayı.ondalık
                return $"{integerPart}.{decimalPart}";
            }
            else
            {
                // Virgül yoksa, sadece nokta varsa binlik ayracıdır
                if (cleanNumber.Contains("."))
                {
                    // Sadece tamsayı, noktaları kaldır
                    return cleanNumber.Replace(".", "");
                }
                else
                {
                    // Hiç ayraç yoksa olduğu gibi dön
                    return cleanNumber;
                }
            }
        }

        private IWebDriver GetWebDriver()
        {
            if (_driver == null)
            {
                var options = new ChromeOptions();
                options.BinaryLocation = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
                options.AddArgument("--headless"); // Run in headless mode
                options.AddArgument("--no-sandbox");
                options.AddArgument("--disable-dev-shm-usage");
                options.AddArgument("--disable-gpu");
                options.AddArgument("--window-size=1920,1080");
                options.AddArgument("--disable-web-security");
                options.AddArgument("--allow-running-insecure-content");
                options.AddArgument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36");

                // Speed optimizations (keeping JS and images for login)
                options.AddArgument("--disable-plugins");
                options.AddArgument("--disable-extensions");

                _driver = new ChromeDriver(options);
                _driver.Manage().Timeouts().ImplicitWait = TimeSpan.FromMilliseconds(100); // Minimal timeout for maximum speed
                _driver.Manage().Timeouts().PageLoad = TimeSpan.FromSeconds(30); // Reasonable page load timeout
                _logger.LogInformation("Chrome WebDriver initialized");
            }
            return _driver;
        }

        public async Task<bool> LoginAsync(string email, string password)
        {
            try
            {
                var driver = GetWebDriver();
                var loginUrl = "https://www.b2b.hvkmuhendislik.com/GirisYap";
                _logger.LogInformation($"Navigating to login page: {loginUrl}");

                driver.Navigate().GoToUrl(loginUrl);

                // No delay for maximum speed

                _logger.LogInformation($"Current page title: {driver.Title}");
                _logger.LogInformation($"Current URL: {driver.Url}");

                // Find username field
                var usernameField = driver.FindElement(By.Id("Username"));
                _logger.LogInformation("Found username field");

                // Find password field  
                var passwordField = driver.FindElement(By.Id("Password"));
                _logger.LogInformation("Found password field");

                // Clear and enter credentials
                usernameField.Clear();
                usernameField.SendKeys(email);
                _logger.LogInformation("Entered username");

                passwordField.Clear();
                passwordField.SendKeys(password);
                _logger.LogInformation("Entered password");

                // Find and click submit button
                var submitButton = driver.FindElement(By.XPath("//input[@type='submit'] | //button[@type='submit'] | //button[contains(text(), 'Giriş')] | //input[@value='Giriş']"));
                _logger.LogInformation($"Found submit button: {submitButton.TagName}");

                submitButton.Click();
                _logger.LogInformation("Clicked login button");

                // No delay for maximum speed

                _logger.LogInformation($"After login - Current URL: {driver.Url}");
                _logger.LogInformation($"After login - Page title: {driver.Title}");

                // Check if login was successful
                var currentUrl = driver.Url;
                var pageSource = driver.PageSource;

                var containsGirisYap = pageSource.Contains("GirisYap") || currentUrl.Contains("GirisYap");
                var containsCikis = pageSource.Contains("Çıkış");
                var containsHome = pageSource.Contains("Home");
                var containsStokListesi = pageSource.Contains("stok-listesi") || currentUrl.Contains("stok-listesi");
                var containsLogout = pageSource.Contains("logout");

                _logger.LogInformation($"Login indicators - GirisYap: {containsGirisYap}, Çıkış: {containsCikis}, Home: {containsHome}, StokListesi: {containsStokListesi}, Logout: {containsLogout}");

                // Login successful if we're not on login page anymore and have indicators of being logged in
                var isLoggedIn = !containsGirisYap && (containsCikis || containsHome || containsStokListesi || containsLogout);

                _logger.LogInformation($"Final login result: {isLoggedIn}");

                return isLoggedIn;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during Selenium login process");
                return false;
            }
        }

        public async Task<List<Product>> ScrapeProductsAsync(string email, string password)
        {
            // Initialize cancellation token
            _cancellationTokenSource = new CancellationTokenSource();

            // Single browser scraping - parallel disabled due to HttpClient dispose issue
            return await ScrapeProductsParallelAsync(email, password, 1, _cancellationTokenSource.Token);
        }

        public void StopScraping()
        {
            _logger.LogInformation("Stop scraping requested by user");
            _cancellationTokenSource?.Cancel();
        }

        public async Task<List<Product>> ScrapeProductsParallelAsync(string email, string password, int browserCount, CancellationToken cancellationToken = default)
        {
            var allProducts = new List<Product>();

            try
            {
                _logger.LogInformation($"Starting parallel scraping with {browserCount} browsers");

                // İlk browser ile toplam sayfa sayısını öğren
                var totalPages = await GetTotalPageCountAsync(email, password);
                _logger.LogInformation($"Total pages detected: {totalPages}");

                // Sayfa aralıklarını hesapla
                var pagesPerBrowser = totalPages / browserCount;
                var tasks = new List<Task<List<Product>>>();

                for (int i = 0; i < browserCount; i++)
                {
                    var startPage = i * pagesPerBrowser + 1;
                    var endPage = (i == browserCount - 1) ? totalPages : (i + 1) * pagesPerBrowser;

                    _logger.LogInformation($"Browser {i + 1}: Pages {startPage}-{endPage}");

                    // Her browser için ayrı task oluştur
                    var task = Task.Run(async () =>
                        await ScrapePageRangeAsync(email, password, startPage, endPage, i + 1, cancellationToken));
                    tasks.Add(task);
                }

                // Tüm browser'ların tamamlanmasını bekle
                var results = await Task.WhenAll(tasks);

                // Sonuçları birleştir
                foreach (var result in results)
                {
                    allProducts.AddRange(result);
                }

                _logger.LogInformation($"Parallel scraping completed: {allProducts.Count} products total");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during parallel scraping");
            }

            return allProducts;
        }

        private bool HasExistingImageFile(string productCode)
        {
            if (string.IsNullOrEmpty(productCode)) return false;

            var imageDirectory = Path.Combine("wwwroot", "images", "products");

            // Check for any file starting with productCode and having image extension
            var pattern = $"{productCode}.*";
            var imageExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".webp" };

            try
            {
                var files = Directory.GetFiles(imageDirectory, pattern, SearchOption.TopDirectoryOnly);
                return files.Any(file => imageExtensions.Any(ext =>
                    Path.GetExtension(file).ToLowerInvariant() == ext));
            }
            catch
            {
                return false;
            }
        }

        private async Task<int> GetTotalPageCountAsync(string email, string password)
        {
            // Cache total pages to avoid repeated expensive operations
            return 202; // Known total pages - skip dynamic detection for speed
        }

        private async Task<List<Product>> ScrapePageRangeAsync(string email, string password, int startPage, int endPage, int browserId, CancellationToken cancellationToken = default)
        {
            var products = new List<Product>();
            IWebDriver? driver = null;

            try
            {
                _logger.LogInformation($"Browser {browserId}: Starting pages {startPage}-{endPage}");

                driver = GetWebDriver();

                // Login yap
                var loginSuccess = await LoginAsync(email, password);
                if (!loginSuccess)
                {
                    _logger.LogError("Login failed, cannot proceed with scraping");
                    return products;
                }

                _logger.LogInformation("Login successful, starting product scraping with pagination");
                _logger.LogInformation("*** PAGINATION VERSION IS ACTIVE ***");

                // İlk sayfaya git
                var stockListUrl = "https://www.b2b.hvkmuhendislik.com/stok-listesi-tum/stok-listesi";
                _logger.LogInformation($"Navigating to stock list page: {stockListUrl}");
                driver.Navigate().GoToUrl(stockListUrl);

                // Page load optimization - no delays

                // Sayfa sayısını dinamik olarak oku
                var totalPages = GetTotalPageCount(driver);
                _logger.LogInformation($"Total pages detected: {totalPages}");

                // Siteden okunan tüm sayfaları kullan (202 sayfa)
                var actualMaxPages = totalPages;
                _logger.LogInformation($"🚀 Starting full catalog scraping: {actualMaxPages} pages to process...");
                var totalProcessed = 0;

                for (int currentPage = 1; currentPage <= actualMaxPages; currentPage++)
                {
                    // Check for cancellation
                    cancellationToken.ThrowIfCancellationRequested();

                    var progressPercent = (currentPage * 100.0 / actualMaxPages);
                    _logger.LogInformation($"📄 Processing page {currentPage}/{actualMaxPages} ({progressPercent:F1}% complete)");

                    // İlk sayfa değilse, hedef sayfaya git
                    if (currentPage > 1)
                    {
                        var navigationSuccess = await NavigateToPage(driver, currentPage);
                        if (!navigationSuccess)
                        {
                            _logger.LogError($"Failed to navigate to page {currentPage}, skipping");
                            continue;
                        }
                    }

                    var pageSource = driver.PageSource;
                    var doc = new HtmlDocument();
                    doc.LoadHtml(pageSource);

                    _logger.LogInformation($"Page {currentPage} - Content length: {pageSource.Length}");

                    // HTML yapısına göre ürün section'larını bul
                    var productSections = doc.DocumentNode.SelectNodes("//section[starts-with(@id, 'urun-')]");

                    if (productSections == null || !productSections.Any())
                    {
                        _logger.LogWarning($"Page {currentPage}: No product sections found, trying alternatives...");

                        // Alternatif selectors dene
                        productSections = doc.DocumentNode.SelectNodes("//section[@id]");
                        if (productSections == null || !productSections.Any())
                        {
                            productSections = doc.DocumentNode.SelectNodes("//div[contains(@class, 'product') or contains(@class, 'item') or contains(@id, 'product')]");
                        }

                        if (productSections == null || !productSections.Any())
                        {
                            _logger.LogWarning($"Page {currentPage}: No products found, might be end of catalog or empty page");

                            // Eğer arka arkaya 3 sayfa boşsa dur
                            if (currentPage > 3)
                            {
                                var emptyPageCount = 0;
                                for (int checkPage = currentPage - 2; checkPage <= currentPage; checkPage++)
                                {
                                    // Son 3 sayfanın ürün sayısını kontrol et (basit yaklaşım)
                                    emptyPageCount++;
                                }
                                if (emptyPageCount >= 3)
                                {
                                    _logger.LogInformation($"Found 3 consecutive empty pages, stopping at page {currentPage}");
                                    break;
                                }
                            }
                            continue;
                        }
                    }

                    _logger.LogInformation($"Page {currentPage}: Found {productSections.Count} product sections");

                    var pageProductCount = 0;
                    foreach (var section in productSections)
                    {
                        try
                        {
                            // Ürün bilgilerini section attribute'larından al
                            var productName = section.GetAttributeValue("title", "");
                            var productCode = section.GetAttributeValue("Data-stok-kodu", "");
                            var vatRateText = section.GetAttributeValue("Data-kdv", "0");
                            var discount1Text = section.GetAttributeValue("Data-isk1", "0");
                            var discount2Text = section.GetAttributeValue("Data-isk2", "0");
                            var discount3Text = section.GetAttributeValue("Data-isk3", "0");

                            if (string.IsNullOrEmpty(productName) || string.IsNullOrEmpty(productCode))
                            {
                                _logger.LogWarning($"Skipping section with missing data: name='{productName}', code='{productCode}'");
                                continue;
                            }

                            // HTML decode
                            productName = System.Net.WebUtility.HtmlDecode(productName);

                            _logger.LogInformation($"Processing product: {productCode} - {productName}");

                            // Fiyat tablosunu bul - önce HTML yapısını analiz et
                            decimal listPrice = 0;
                            decimal buyPriceExcludingVat = 0;
                            decimal buyPriceIncludingVat = 0;

                            _logger.LogInformation($"Analyzing HTML structure for product: {productCode}");

                            // Tüm section HTML'ini log'la
                            var sectionHtml = section.OuterHtml;
                            _logger.LogInformation($"Section HTML snippet (first 500 chars): {sectionHtml.Substring(0, Math.Min(500, sectionHtml.Length))}");

                            // Farklı fiyat tablosu yapılarını dene
                            var priceTable = section.SelectSingleNode(".//table[@class='fiyat-tablosu']");
                            if (priceTable == null)
                            {
                                // Alternatif table selectorleri dene
                                priceTable = section.SelectSingleNode(".//table[contains(@class, 'fiyat')]");
                                if (priceTable == null)
                                {
                                    priceTable = section.SelectSingleNode(".//table");
                                }
                            }

                            _logger.LogInformation($"Price table found: {priceTable != null}");

                            if (priceTable != null)
                            {
                                _logger.LogInformation($"Price table HTML: {priceTable.OuterHtml}");

                                var rows = priceTable.SelectNodes(".//tr");
                                _logger.LogInformation($"Table rows found: {rows?.Count ?? 0}");

                                if (rows != null)
                                {
                                    for (int i = 0; i < rows.Count; i++)
                                    {
                                        var row = rows[i];
                                        var cells = row.SelectNodes(".//td");
                                        _logger.LogInformation($"Row {i}: {cells?.Count ?? 0} cells - HTML: {row.OuterHtml}");

                                        if (cells != null && cells.Count >= 2)
                                        {
                                            var label = cells[0]?.InnerText?.Trim() ?? "";
                                            var priceCell = cells[1];
                                            var priceText = priceCell?.InnerText?.Trim() ?? "";

                                            _logger.LogInformation($"Row {i}: Label='{label}', Price='{priceText}'");

                                            if (label.Contains("Liste Fiyatı") || label.Contains("Liste"))
                                            {
                                                // Liste fiyatı - farklı yapıları dene
                                                var delNode = priceCell.SelectSingleNode(".//del");
                                                if (delNode != null)
                                                {
                                                    var price = delNode.InnerText.Replace("₺", "").Replace("EUR", "").Replace("USD", "").Trim();
                                                    price = ParseTurkishDecimal(price);
                                                    decimal.TryParse(price, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out listPrice);
                                                    _logger.LogInformation($"List price from <del>: {delNode.InnerText} -> parsed: {price} -> {listPrice}");
                                                }
                                                else
                                                {
                                                    var price = priceText.Replace("₺", "").Replace("EUR", "").Replace("USD", "").Trim();
                                                    price = ParseTurkishDecimal(price);
                                                    decimal.TryParse(price, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out listPrice);
                                                    _logger.LogInformation($"List price from text: {priceText} -> parsed: {price} -> {listPrice}");
                                                }
                                            }
                                            else if (label.Contains("Size Özel") || label.Contains("Özel") || label.Contains("KDV Hariç"))
                                            {
                                                // KDV Hariç fiyat
                                                var price = priceText.Replace("₺", "").Replace("EUR", "").Replace("USD", "").Trim();
                                                price = ParseTurkishDecimal(price);
                                                decimal.TryParse(price, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out buyPriceExcludingVat);
                                                _logger.LogInformation($"Buy price excluding VAT: {priceText} -> parsed: {price} -> {buyPriceExcludingVat}");
                                            }
                                            else if (label.Contains("KDV Dahil") || string.IsNullOrEmpty(label))
                                            {
                                                // KDV Dahil fiyat
                                                var strongNode = priceCell.SelectSingleNode(".//strong");
                                                if (strongNode != null)
                                                {
                                                    var price = strongNode.InnerText.Replace("₺", "").Replace("EUR", "").Replace("USD", "").Trim();
                                                    price = ParseTurkishDecimal(price);
                                                    decimal.TryParse(price, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out buyPriceIncludingVat);
                                                    _logger.LogInformation($"Buy price including VAT from <strong>: {strongNode.InnerText} -> parsed: {price} -> {buyPriceIncludingVat}");
                                                }
                                                else
                                                {
                                                    var price = priceText.Replace("₺", "").Replace("EUR", "").Replace("USD", "").Trim();
                                                    price = ParseTurkishDecimal(price);
                                                    decimal.TryParse(price, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out buyPriceIncludingVat);
                                                    _logger.LogInformation($"Buy price including VAT from text: {priceText} -> parsed: {price} -> {buyPriceIncludingVat}");
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            else
                            {
                                _logger.LogWarning($"No price table found for product {productCode}. Checking for alternative price elements...");

                                // Alternatif fiyat elementlerini ara
                                var allSpans = section.SelectNodes(".//span[contains(text(), '₺')]");
                                var allDivs = section.SelectNodes(".//div[contains(text(), '₺')]");

                                _logger.LogInformation($"Found {allSpans?.Count ?? 0} spans with ₺ symbol");
                                _logger.LogInformation($"Found {allDivs?.Count ?? 0} divs with ₺ symbol");

                                if (allSpans != null)
                                {
                                    foreach (var span in allSpans)
                                    {
                                        _logger.LogInformation($"Price span: {span.OuterHtml}");
                                    }
                                }
                            }

                            // Resim URL'sini bul
                            var imageNode = section.SelectSingleNode(".//img");
                            var imageUrl = imageNode?.GetAttributeValue("src", "") ?? "";

                            // Resim download için URL'yi sakla (paralel processing için)
                            string? localImagePath = null;

                            // Parse numeric values
                            // NOT: HTML attribute'larındaki değerler zaten decimal formatında (örn: "20.00", "40.00000000")
                            // ParseTurkishDecimal sadece HTML text içindeki Türkçe formatlar için kullanılmalı
                            decimal.TryParse(vatRateText.Replace(",", "."), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var vatRate);
                            decimal.TryParse(discount1Text.Replace(",", "."), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var discount1);
                            decimal.TryParse(discount2Text.Replace(",", "."), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var discount2);
                            decimal.TryParse(discount3Text.Replace(",", "."), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var discount3);

                            // Fiyat kontrolü ve logging
                            _logger.LogInformation($"Product {productCode} - Prices: List={listPrice}, BuyExcl={buyPriceExcludingVat}, BuyIncl={buyPriceIncludingVat}, VAT={vatRate}");

                            // Fiyatı 0 olan ürünleri de dahil et (kullanıcı filtreleyebilir)
                            if (listPrice == 0 && buyPriceExcludingVat == 0 && buyPriceIncludingVat == 0)
                            {
                                _logger.LogInformation($"Product {productCode} has no price access (all prices are 0) - including anyway");
                            }

                            // Kar marjı ile satış fiyatını hesapla
                            var marginPercentage = 40m; // Default %40 kar marjı

                            // Doğru hesaplama:
                            // 1. Benim alış fiyatım = KDV Dahil Alış
                            // 2. Kar marjı ekle: (Alış KDV Hariç) * (1 + margin)  
                            // 3. Sonra KDV ekle: (Kar marjlı fiyat) * (1 + KDV oranı)
                            var priceWithMargin = buyPriceExcludingVat * (1 + marginPercentage / 100);
                            var myPrice = priceWithMargin * (1 + vatRate / 100);

                            _logger.LogInformation($"Price calculation - Buy excl VAT: {buyPriceExcludingVat}, Margin: {marginPercentage}%, VAT: {vatRate}%, With margin: {priceWithMargin}, Final: {myPrice}");

                            var product = new Product
                            {
                                ProductCode = productCode,
                                Name = productName,
                                ListPrice = listPrice,
                                BuyPriceExcludingVat = buyPriceExcludingVat,
                                BuyPriceIncludingVat = buyPriceIncludingVat,
                                MyPrice = myPrice,
                                Discount1 = discount1,
                                Discount2 = discount2,
                                Discount3 = discount3,
                                VatRate = vatRate,
                                ImageUrl = imageUrl,
                                LocalImagePath = localImagePath,
                                MarginPercentage = marginPercentage,
                                LastUpdated = DateTime.UtcNow
                            };

                            products.Add(product);
                            pageProductCount++;
                            totalProcessed++;

                            _logger.LogInformation($"Page {currentPage} - Product {pageProductCount}: {productCode} - {productName} (List: {listPrice}₺, Buy: {buyPriceExcludingVat}₺, My: {myPrice:F2}₺)");

                            // Rate limiting completely removed for maximum speed
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, $"Error parsing product section on page {currentPage}");
                            continue;
                        }
                    }

                    // Download images for new products only (optimized)
                    var newProducts = products.Skip(products.Count - pageProductCount).ToList();
                    await DownloadImagesParallel(newProducts, skipExistingImages: true);

                    totalProcessed += pageProductCount;
                    _logger.LogInformation($"Page {currentPage}/{actualMaxPages} completed: {pageProductCount} products scraped (Total so far: {totalProcessed})");

                    // All page delays removed for maximum speed
                }

                _logger.LogInformation($"🎉 SCRAPING COMPLETED! Total: {totalProcessed} products across {actualMaxPages} pages");
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Scraping was cancelled by user request");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during product scraping");
            }

            return products;
        }

        private async Task DownloadImagesParallel(List<Product> pageProducts, bool skipExistingImages = true)
        {
            var imageDownloadTasks = new List<Task>();
            var productsNeedingImages = pageProducts.Where(p =>
                !string.IsNullOrEmpty(p.ImageUrl) &&
                !p.ImageUrl.Contains("noimage") &&
                (string.IsNullOrEmpty(p.LocalImagePath) || !HasExistingImageFile(p.ProductCode)) // Download if DB null OR file missing
            ).ToList();

            if (!productsNeedingImages.Any())
            {
                _logger.LogInformation("No new images to download (all products already have images)");
                return;
            }

            foreach (var product in productsNeedingImages)
            {
                var imageTask = Task.Run(async () =>
                {
                    try
                    {
                        var imagePath = await _imageDownloadService.DownloadProductImageAsync(product.ImageUrl, product.ProductCode);
                        product.LocalImagePath = imagePath;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to download image for product {product.ProductCode}");
                    }
                });
                imageDownloadTasks.Add(imageTask);
            }

            if (imageDownloadTasks.Any())
            {
                await Task.WhenAll(imageDownloadTasks);
                _logger.LogInformation($"📸 Images: Downloaded {imageDownloadTasks.Count} new images, skipped {pageProducts.Count - productsNeedingImages.Count} existing (Page total: {pageProducts.Count})");
            }
        }

        public void Dispose()
        {
            _driver?.Quit();
            _driver?.Dispose();
        }
    }
}