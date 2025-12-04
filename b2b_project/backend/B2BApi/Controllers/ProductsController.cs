using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Models;
using B2BApi.Services;

namespace B2BApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly B2BScraperService _scraperService;
        private readonly ILogger<ProductsController> _logger;

        public ProductsController(ApplicationDbContext context, B2BScraperService scraperService, ILogger<ProductsController> logger)
        {
            _context = context;
            _scraperService = scraperService;
            _logger = logger;
        }

        // GET: api/products
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Product>>> GetProducts([FromQuery] bool includeDeleted = false)
        {
            try
            {
                var query = _context.Products.AsQueryable();

                if (!includeDeleted)
                {
                    query = query.Where(p => !p.IsDeleted);
                }

                var products = await query
                    .OrderBy(p => p.Name)
                    .ToListAsync();
                return Ok(products);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting products");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/products/search/{term}
        [HttpGet("search/{term}")]
        public async Task<ActionResult<IEnumerable<Product>>> SearchProducts(string term, [FromQuery] bool includeDeleted = false)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(term))
                {
                    return BadRequest("Search term cannot be empty");
                }

                var query = _context.Products
                    .Where(p => p.Name.Contains(term) || p.ProductCode.Contains(term));

                if (!includeDeleted)
                {
                    query = query.Where(p => !p.IsDeleted);
                }

                var products = await query
                    .OrderBy(p => p.Name)
                    .ToListAsync();

                return Ok(products);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error searching products with term: {term}");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/products/{code}/margin
        [HttpPut("{code}/margin")]
        public async Task<IActionResult> UpdateMargin(string code, [FromBody] decimal marginPercentage)
        {
            try
            {
                if (marginPercentage < 0 || marginPercentage > 100)
                {
                    return BadRequest("Margin percentage must be between 0 and 100");
                }

                var product = await _context.Products
                    .FirstOrDefaultAsync(p => p.ProductCode == code);

                if (product == null)
                {
                    return NotFound($"Product with code {code} not found");
                }

                product.MarginPercentage = marginPercentage;
                
                // Doğru hesaplama: Kar marjını KDV hariç fiyata ekle, sonra KDV uygula
                var priceWithMargin = product.BuyPriceExcludingVat * (1 + marginPercentage / 100);
                product.MyPrice = priceWithMargin * (1 + product.VatRate / 100);
                
                product.LastUpdated = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                return Ok(product);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating margin for product: {code}");
                return StatusCode(500, "Internal server error");
            }
        }

        // POST: api/products/scrape
        [HttpPost("scrape")]
        public async Task<IActionResult> ScrapeProducts([FromBody] LoginCredentials credentials)
        {
            try
            {
                if (credentials == null || string.IsNullOrWhiteSpace(credentials.Email) || string.IsNullOrWhiteSpace(credentials.Password))
                {
                    return BadRequest("Email and password are required");
                }

                _logger.LogInformation("Starting manual scraping process");
                
                var scrapedProducts = await _scraperService.ScrapeProductsAsync(credentials.Email, credentials.Password);
                
                if (!scrapedProducts.Any())
                {
                    return BadRequest("No products were scraped");
                }

                // Her scraping'de tüm ürünleri güncelle veya yeni ürünleri ekle
                foreach (var scrapedProduct in scrapedProducts)
                {
                    var existingProduct = await _context.Products
                        .FirstOrDefaultAsync(p => p.ProductCode == scrapedProduct.ProductCode);

                    if (existingProduct != null)
                    {
                        // Mevcut ürünü tamamen güncelle - kar marjını koru ama diğer tüm alanları güncelle
                        var preservedMargin = existingProduct.MarginPercentage; // Kullanıcının belirlediği kar marjını koru
                        
                        existingProduct.Name = scrapedProduct.Name;
                        existingProduct.ListPrice = scrapedProduct.ListPrice;
                        existingProduct.BuyPriceExcludingVat = scrapedProduct.BuyPriceExcludingVat;
                        existingProduct.BuyPriceIncludingVat = scrapedProduct.BuyPriceIncludingVat;
                        existingProduct.Discount1 = scrapedProduct.Discount1;
                        existingProduct.Discount2 = scrapedProduct.Discount2;
                        existingProduct.Discount3 = scrapedProduct.Discount3;
                        existingProduct.VatRate = scrapedProduct.VatRate;
                        existingProduct.ImageUrl = scrapedProduct.ImageUrl;
                        existingProduct.LocalImagePath = scrapedProduct.LocalImagePath;
                        existingProduct.MarginPercentage = preservedMargin; // Kar marjını koru
                        
                        // Yeni verilere göre satış fiyatını yeniden hesapla
                        var priceWithMargin = existingProduct.BuyPriceExcludingVat * (1 + existingProduct.MarginPercentage / 100);
                        existingProduct.MyPrice = priceWithMargin * (1 + existingProduct.VatRate / 100);
                        existingProduct.LastUpdated = DateTime.UtcNow;
                        
                        _logger.LogInformation($"Updated existing product: {existingProduct.ProductCode} - List: {existingProduct.ListPrice}, Buy: {existingProduct.BuyPriceExcludingVat}, Sell: {existingProduct.MyPrice}");
                    }
                    else
                    {
                        // Yeni ürün ekle
                        _context.Products.Add(scrapedProduct);
                        _logger.LogInformation($"Added new product: {scrapedProduct.ProductCode} - List: {scrapedProduct.ListPrice}, Buy: {scrapedProduct.BuyPriceExcludingVat}, Sell: {scrapedProduct.MyPrice}");
                    }
                }

                await _context.SaveChangesAsync();

                var result = new
                {
                    Message = "Scraping completed successfully",
                    ProductCount = scrapedProducts.Count,
                    Timestamp = DateTime.UtcNow
                };

                _logger.LogInformation($"Scraping completed: {scrapedProducts.Count} products processed");
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during scraping process");
                return StatusCode(500, "Internal server error during scraping");
            }
        }

        // POST: api/products/stop-scraping
        [HttpPost("stop-scraping")]
        public IActionResult StopScraping()
        {
            try
            {
                _logger.LogInformation("Stop scraping requested");
                _scraperService.StopScraping();
                return Ok(new { Message = "Scraping stop request sent" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error stopping scraping");
                return StatusCode(500, "Error stopping scraping");
            }
        }

        // GET: api/products/{code}
        [HttpGet("{code}")]
        public async Task<ActionResult<Product>> GetProduct(string code)
        {
            try
            {
                var product = await _context.Products
                    .FirstOrDefaultAsync(p => p.ProductCode == code);

                if (product == null)
                {
                    return NotFound($"Product with code {code} not found");
                }

                return Ok(product);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting product: {code}");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/products/outdated
        [HttpGet("outdated")]
        public async Task<ActionResult<object>> GetOutdatedProducts([FromQuery] int months = 3)
        {
            try
            {
                var thresholdDate = DateTime.UtcNow.AddMonths(-months);

                var outdatedProducts = await _context.Products
                    .Where(p => !p.IsDeleted && p.LastUpdated < thresholdDate)
                    .OrderBy(p => p.LastUpdated)
                    .ToListAsync();

                var result = new
                {
                    ThresholdDate = thresholdDate,
                    ThresholdMonths = months,
                    Count = outdatedProducts.Count,
                    Products = outdatedProducts
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting outdated products");
                return StatusCode(500, "Internal server error");
            }
        }

        // DELETE: api/products/{code}/soft
        [HttpDelete("{code}/soft")]
        public async Task<IActionResult> SoftDeleteProduct(string code)
        {
            try
            {
                var product = await _context.Products
                    .FirstOrDefaultAsync(p => p.ProductCode == code);

                if (product == null)
                {
                    return NotFound($"Product with code {code} not found");
                }

                if (product.IsDeleted)
                {
                    return BadRequest("Product is already deleted");
                }

                product.IsDeleted = true;
                product.DeletedAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Soft deleted product: {code}");
                return Ok(new { Message = $"Product {code} has been soft deleted", Product = product });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error soft deleting product: {code}");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/products/{code}/restore
        [HttpPut("{code}/restore")]
        public async Task<IActionResult> RestoreProduct(string code)
        {
            try
            {
                var product = await _context.Products
                    .FirstOrDefaultAsync(p => p.ProductCode == code);

                if (product == null)
                {
                    return NotFound($"Product with code {code} not found");
                }

                if (!product.IsDeleted)
                {
                    return BadRequest("Product is not deleted");
                }

                product.IsDeleted = false;
                product.DeletedAt = null;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Restored product: {code}");
                return Ok(new { Message = $"Product {code} has been restored", Product = product });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error restoring product: {code}");
                return StatusCode(500, "Internal server error");
            }
        }

        // DELETE: api/products/{code}/bulk-soft
        [HttpPost("bulk-soft-delete")]
        public async Task<IActionResult> BulkSoftDelete([FromBody] List<string> productCodes)
        {
            try
            {
                if (productCodes == null || !productCodes.Any())
                {
                    return BadRequest("Product codes list cannot be empty");
                }

                var products = await _context.Products
                    .Where(p => productCodes.Contains(p.ProductCode) && !p.IsDeleted)
                    .ToListAsync();

                if (!products.Any())
                {
                    return NotFound("No products found to delete");
                }

                foreach (var product in products)
                {
                    product.IsDeleted = true;
                    product.DeletedAt = DateTime.UtcNow;
                }

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Bulk soft deleted {products.Count} products");
                return Ok(new {
                    Message = $"Successfully soft deleted {products.Count} products",
                    DeletedCount = products.Count,
                    ProductCodes = products.Select(p => p.ProductCode).ToList()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error bulk soft deleting products");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/products/all - Union of Products and ManualProducts
        [HttpGet("all")]
        public async Task<ActionResult<IEnumerable<UnifiedProduct>>> GetAllProducts([FromQuery] bool includeDeleted = false)
        {
            try
            {
                // Get API Products
                var apiProducts = await _context.Products
                    .Where(p => includeDeleted || !p.IsDeleted)
                    .Select(p => new UnifiedProduct
                    {
                        Id = p.Id,
                        ProductCode = p.ProductCode,
                        Name = p.Name,
                        MyPrice = p.MyPrice,
                        SalePriceExcludingVat = p.SalePriceExcludingVat,
                        SalePriceIncludingVat = p.SalePriceIncludingVat,
                        MarginPercentage = p.MarginPercentage,
                        VatRate = p.VatRate,
                        LastUpdated = p.LastUpdated,
                        IsManual = false,
                        IsDeleted = p.IsDeleted,
                        // API Product specific fields
                        ListPrice = p.ListPrice,
                        BuyPriceExcludingVat = p.BuyPriceExcludingVat,
                        BuyPriceIncludingVat = p.BuyPriceIncludingVat,
                        Discount1 = p.Discount1,
                        Discount2 = p.Discount2,
                        Discount3 = p.Discount3,
                        ImageUrl = p.ImageUrl,
                        LocalImagePath = p.LocalImagePath
                    })
                    .ToListAsync();

                // Get Manual Products
                var manualProducts = await _context.ManualProducts
                    .Where(p => includeDeleted || !p.IsDeleted)
                    .Select(p => new UnifiedProduct
                    {
                        Id = p.Id,
                        ProductCode = p.ProductCode,
                        Name = p.Name,
                        MyPrice = p.MyPrice,
                        SalePriceExcludingVat = p.SalePriceExcludingVat,
                        SalePriceIncludingVat = p.SalePriceIncludingVat,
                        MarginPercentage = p.ProfitMargin,
                        VatRate = p.VatRate,
                        LastUpdated = p.LastUpdated,
                        IsManual = true,
                        IsDeleted = p.IsDeleted,
                        // Manual Product specific fields - Map BuyPrice to both fields for Flutter compatibility
                        BuyPrice = p.BuyPrice,
                        BuyPriceExcludingVat = p.BuyPrice, // Map to excluding VAT field
                        BuyPriceIncludingVat = p.BuyPrice * (1 + p.VatRate / 100), // Calculate including VAT
                        CreatedAt = p.CreatedAt
                    })
                    .ToListAsync();

                // Union and sort
                var allProducts = apiProducts
                    .Concat(manualProducts)
                    .OrderBy(p => p.Name)
                    .ToList();

                return Ok(allProducts);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting all products (union)");
                return StatusCode(500, "Internal server error");
            }
        }

    }
}