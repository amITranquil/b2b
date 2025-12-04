using System.Net.Http;

namespace B2BApi.Services
{
    public class ImageDownloadService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<ImageDownloadService> _logger;
        private readonly string _imageDirectory;

        public ImageDownloadService(HttpClient httpClient, ILogger<ImageDownloadService> logger, IWebHostEnvironment env)
        {
            _httpClient = httpClient;
            _logger = logger;
            _imageDirectory = Path.Combine(env.WebRootPath, "images", "products");
            
            // Klasör yoksa oluştur
            if (!Directory.Exists(_imageDirectory))
            {
                Directory.CreateDirectory(_imageDirectory);
                _logger.LogInformation($"Created image directory: {_imageDirectory}");
            }
        }

        public async Task<string?> DownloadProductImageAsync(string imageUrl, string productCode)
        {
            try
            {
                if (string.IsNullOrEmpty(imageUrl) || string.IsNullOrEmpty(productCode))
                {
                    _logger.LogWarning("Image URL or product code is empty");
                    return null;
                }

                // URL'yi düzelt (backslash'leri forward slash'e çevir)
                var cleanUrl = imageUrl.Replace("\\", "/");
                if (!cleanUrl.StartsWith("http"))
                {
                    cleanUrl = "https://www.b2b.hvkmuhendislik.com" + cleanUrl;
                }

                _logger.LogInformation($"Downloading image for product {productCode}: {cleanUrl}");

                // HTTP isteği gönder
                var response = await _httpClient.GetAsync(cleanUrl);
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning($"Failed to download image for {productCode}. Status: {response.StatusCode}");
                    return null;
                }

                // Dosya uzantısını belirle
                var contentType = response.Content.Headers.ContentType?.MediaType;
                var extension = GetFileExtension(contentType, cleanUrl);
                
                // Dosya adını oluştur
                var fileName = $"{productCode}{extension}";
                var filePath = Path.Combine(_imageDirectory, fileName);

                // Resmi dosyaya kaydet
                var imageBytes = await response.Content.ReadAsByteArrayAsync();
                await File.WriteAllBytesAsync(filePath, imageBytes);

                _logger.LogInformation($"Image saved: {filePath}");

                // Relative path döndür
                return $"images/products/{fileName}";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error downloading image for product {productCode}");
                return null;
            }
        }

        private string GetFileExtension(string? contentType, string url)
        {
            // Content-Type'dan uzantı belirle
            var extension = contentType switch
            {
                "image/jpeg" => ".jpg",
                "image/jpg" => ".jpg", 
                "image/png" => ".png",
                "image/gif" => ".gif",
                "image/webp" => ".webp",
                _ => null
            };

            // Content-Type yoksa URL'den uzantı çıkar
            if (string.IsNullOrEmpty(extension))
            {
                var urlExtension = Path.GetExtension(url.Split('?')[0]); // Query string'i kaldır
                extension = string.IsNullOrEmpty(urlExtension) ? ".jpg" : urlExtension;
            }

            return extension;
        }

        public bool ImageExists(string productCode)
        {
            var possibleExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            
            foreach (var ext in possibleExtensions)
            {
                var filePath = Path.Combine(_imageDirectory, $"{productCode}{ext}");
                if (File.Exists(filePath))
                {
                    return true;
                }
            }
            
            return false;
        }

        public string? GetLocalImagePath(string productCode)
        {
            var possibleExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            
            foreach (var ext in possibleExtensions)
            {
                var fileName = $"{productCode}{ext}";
                var filePath = Path.Combine(_imageDirectory, fileName);
                if (File.Exists(filePath))
                {
                    return $"images/products/{fileName}";
                }
            }
            
            return null;
        }
    }
}