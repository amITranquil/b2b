using Microsoft.AspNetCore.Mvc;
using B2BApi.Services;

namespace B2BApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class BackupController : ControllerBase
    {
        private readonly ILogger<BackupController> _logger;
        private readonly IConfiguration _configuration;

        public BackupController(ILogger<BackupController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        /// <summary>
        /// Manuel database backup tetikler
        /// </summary>
        [HttpPost("create")]
        public async Task<IActionResult> CreateBackup()
        {
            try
            {
                _logger.LogInformation("📦 Manuel backup başlatıldı");

                var result = await PerformManualBackup();

                return Ok(new
                {
                    success = true,
                    message = "Backup başarıyla oluşturuldu",
                    backupFile = result.FileName,
                    size = $"{result.SizeKB} KB",
                    timestamp = result.Timestamp
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Manuel backup hatası");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Backup oluşturulurken hata",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Tüm backup'ları listeler
        /// </summary>
        [HttpGet("list")]
        public IActionResult ListBackups()
        {
            try
            {
                var backupPath = _configuration["BackupSettings:BackupPath"] ?? "/home/dietpi/b2bapi/backups";

                if (!Directory.Exists(backupPath))
                {
                    return Ok(new { backups = new List<object>(), count = 0 });
                }

                var backupDir = new DirectoryInfo(backupPath);
                var backups = backupDir.GetFiles("b2b_products_backup_*")
                    .OrderByDescending(f => f.CreationTime)
                    .Select(f => new
                    {
                        fileName = f.Name,
                        sizeKB = f.Length / 1024,
                        sizeMB = Math.Round(f.Length / 1024.0 / 1024.0, 2),
                        createdAt = f.CreationTime,
                        age = GetFileAge(f.CreationTime)
                    })
                    .ToList();

                return Ok(new
                {
                    backups = backups,
                    count = backups.Count,
                    totalSizeMB = Math.Round(backups.Sum(b => b.sizeMB), 2)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Backup listesi alınırken hata");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Backup dosyasını indir
        /// </summary>
        [HttpGet("download/{fileName}")]
        public IActionResult DownloadBackup(string fileName)
        {
            try
            {
                var backupPath = _configuration["BackupSettings:BackupPath"] ?? "/home/dietpi/b2bapi/backups";
                var filePath = Path.Combine(backupPath, fileName);

                // Güvenlik: Path traversal saldırılarını önle
                var fullPath = Path.GetFullPath(filePath);
                var backupDir = Path.GetFullPath(backupPath);

                if (!fullPath.StartsWith(backupDir))
                {
                    return BadRequest(new { error = "Invalid file path" });
                }

                if (!System.IO.File.Exists(filePath))
                {
                    return NotFound(new { error = "Backup file not found" });
                }

                var fileBytes = System.IO.File.ReadAllBytes(filePath);
                var contentType = fileName.EndsWith(".gz") ? "application/gzip" : "application/octet-stream";

                _logger.LogInformation("📥 Backup indirildi: {FileName}", fileName);

                return File(fileBytes, contentType, fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Backup indirme hatası: {FileName}", fileName);
                return StatusCode(500, new { error = ex.Message });
            }
        }

        /// <summary>
        /// Eski backup'ları temizler
        /// </summary>
        [HttpPost("cleanup")]
        public async Task<IActionResult> CleanupOldBackups([FromQuery] int? retentionDays = null)
        {
            try
            {
                var backupPath = _configuration["BackupSettings:BackupPath"] ?? "/home/dietpi/b2bapi/backups";
                var days = retentionDays ?? int.Parse(_configuration["BackupSettings:RetentionDays"] ?? "30");

                var cleaned = await CleanOldBackups(backupPath, days);

                return Ok(new
                {
                    success = true,
                    message = $"Eski backup'lar temizlendi",
                    deletedCount = cleaned.Count,
                    deletedFiles = cleaned
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Backup temizleme hatası");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        // Helper methods

        private async Task<BackupResult> PerformManualBackup()
        {
            var backupPath = _configuration["BackupSettings:BackupPath"] ?? "/home/dietpi/b2bapi/backups";

            // Backup klasörünü oluştur
            if (!Directory.Exists(backupPath))
            {
                Directory.CreateDirectory(backupPath);
                _logger.LogInformation("Backup klasörü oluşturuldu: {BackupPath}", backupPath);
            }

            var timestamp = DateTime.Now;
            var timestampStr = timestamp.ToString("yyyy-MM-dd_HH-mm-ss");
            var backupFileName = $"b2b_products_backup_{timestampStr}.db";
            var backupFilePath = Path.Combine(backupPath, backupFileName);

            // Database dosyasının yolunu bul
            var dbPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "b2b_products.db");

            if (!System.IO.File.Exists(dbPath))
            {
                throw new FileNotFoundException($"Database dosyası bulunamadı: {dbPath}");
            }

            // Database'i kopyala
            await Task.Run(() => System.IO.File.Copy(dbPath, backupFilePath, true));

            var fileInfo = new FileInfo(backupFilePath);
            var sizeKB = fileInfo.Length / 1024;

            _logger.LogInformation("✅ Manuel backup başarılı: {FileName} ({Size} KB)",
                backupFileName, sizeKB);

            // Opsiyonel: Sıkıştır
            var compressedFileName = await CompressBackup(backupFilePath);

            return new BackupResult
            {
                FileName = compressedFileName ?? backupFileName,
                SizeKB = sizeKB,
                Timestamp = timestamp
            };
        }

        private async Task<string?> CompressBackup(string backupFilePath)
        {
            try
            {
                var compressedPath = backupFilePath + ".gz";

                using (var originalFileStream = System.IO.File.OpenRead(backupFilePath))
                using (var compressedFileStream = System.IO.File.Create(compressedPath))
                using (var compressionStream = new System.IO.Compression.GZipStream(
                    compressedFileStream, System.IO.Compression.CompressionMode.Compress))
                {
                    await originalFileStream.CopyToAsync(compressionStream);
                }

                // Orijinal dosyayı sil
                System.IO.File.Delete(backupFilePath);

                var compressedInfo = new FileInfo(compressedPath);
                _logger.LogInformation("📦 Backup sıkıştırıldı: {FileName} ({Size} KB)",
                    Path.GetFileName(compressedPath), compressedInfo.Length / 1024);

                return Path.GetFileName(compressedPath);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Backup sıkıştırma hatası (devam ediliyor)");
                return null;
            }
        }

        private async Task<List<string>> CleanOldBackups(string backupPath, int retentionDays)
        {
            var deletedFiles = new List<string>();

            var backupDir = new DirectoryInfo(backupPath);
            if (!backupDir.Exists) return deletedFiles;

            var cutoffDate = DateTime.Now.AddDays(-retentionDays);
            var oldBackups = backupDir.GetFiles("b2b_products_backup_*")
                .Where(f => f.CreationTime < cutoffDate)
                .ToList();

            foreach (var file in oldBackups)
            {
                await Task.Run(() => file.Delete());
                deletedFiles.Add(file.Name);
                _logger.LogInformation("🗑️ Eski backup silindi: {FileName}", file.Name);
            }

            return deletedFiles;
        }

        private string GetFileAge(DateTime creationTime)
        {
            var age = DateTime.Now - creationTime;

            if (age.TotalMinutes < 1)
                return "Az önce";
            if (age.TotalHours < 1)
                return $"{(int)age.TotalMinutes} dakika önce";
            if (age.TotalDays < 1)
                return $"{(int)age.TotalHours} saat önce";
            if (age.TotalDays < 30)
                return $"{(int)age.TotalDays} gün önce";

            return $"{(int)(age.TotalDays / 30)} ay önce";
        }

        private class BackupResult
        {
            public string FileName { get; set; } = string.Empty;
            public long SizeKB { get; set; }
            public DateTime Timestamp { get; set; }
        }
    }
}
