using Microsoft.Extensions.Options;

namespace B2BApi.Services
{
    public class DatabaseBackupService : BackgroundService
    {
        private readonly ILogger<DatabaseBackupService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _backupPath;
        private readonly TimeSpan _backupTime;
        private readonly int _retentionDays;

        public DatabaseBackupService(ILogger<DatabaseBackupService> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
            _backupPath = configuration["BackupSettings:BackupPath"] ?? "/home/dietpi/b2bapi/backups";
            _retentionDays = int.Parse(configuration["BackupSettings:RetentionDays"] ?? "30");

            var backupTimeStr = configuration["BackupSettings:BackupTime"] ?? "00:00";
            var timeParts = backupTimeStr.Split(':');
            _backupTime = new TimeSpan(int.Parse(timeParts[0]), int.Parse(timeParts[1]), 0);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Database Backup Service başlatıldı. Backup zamanı: {BackupTime}", _backupTime);

            while (!stoppingToken.IsCancellationRequested)
            {
                var now = DateTime.Now;
                var nextBackup = now.Date + _backupTime;

                // Eğer bugünkü backup zamanı geçtiyse, yarınki backup zamanını hesapla
                if (now > nextBackup)
                {
                    nextBackup = nextBackup.AddDays(1);
                }

                var delay = nextBackup - now;
                _logger.LogInformation("Sonraki backup zamanı: {NextBackup} ({Delay} sonra)",
                    nextBackup, delay);

                await Task.Delay(delay, stoppingToken);

                if (!stoppingToken.IsCancellationRequested)
                {
                    await PerformBackup();
                    await CleanOldBackups();
                }
            }
        }

        private async Task PerformBackup()
        {
            try
            {
                // Backup klasörünü oluştur
                if (!Directory.Exists(_backupPath))
                {
                    Directory.CreateDirectory(_backupPath);
                    _logger.LogInformation("Backup klasörü oluşturuldu: {BackupPath}", _backupPath);
                }

                var timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
                var backupFileName = $"b2b_products_backup_{timestamp}.db";
                var backupFilePath = Path.Combine(_backupPath, backupFileName);

                // Database dosyasının yolunu bul
                var dbPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "b2b_products.db");

                if (!File.Exists(dbPath))
                {
                    _logger.LogError("Database dosyası bulunamadı: {DbPath}", dbPath);
                    return;
                }

                // Database'i kopyala
                await Task.Run(() => File.Copy(dbPath, backupFilePath, true));

                var fileInfo = new FileInfo(backupFilePath);
                _logger.LogInformation("✅ Database backup başarılı: {FileName} ({Size} KB)",
                    backupFileName, fileInfo.Length / 1024);

                // Opsiyonel: Backup'ı sıkıştır
                await CompressBackup(backupFilePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Database backup hatası");
            }
        }

        private async Task CompressBackup(string backupFilePath)
        {
            try
            {
                var compressedPath = backupFilePath + ".gz";

                using (var originalFileStream = File.OpenRead(backupFilePath))
                using (var compressedFileStream = File.Create(compressedPath))
                using (var compressionStream = new System.IO.Compression.GZipStream(
                    compressedFileStream, System.IO.Compression.CompressionMode.Compress))
                {
                    await originalFileStream.CopyToAsync(compressionStream);
                }

                // Orijinal dosyayı sil, sadece sıkıştırılmış halini tut
                File.Delete(backupFilePath);

                var compressedInfo = new FileInfo(compressedPath);
                _logger.LogInformation("📦 Backup sıkıştırıldı: {FileName} ({Size} KB)",
                    Path.GetFileName(compressedPath), compressedInfo.Length / 1024);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Backup sıkıştırma hatası (devam ediliyor)");
            }
        }

        private async Task CleanOldBackups()
        {
            try
            {
                var backupDir = new DirectoryInfo(_backupPath);
                if (!backupDir.Exists) return;

                var cutoffDate = DateTime.Now.AddDays(-_retentionDays);
                var oldBackups = backupDir.GetFiles("b2b_products_backup_*")
                    .Where(f => f.CreationTime < cutoffDate)
                    .ToList();

                foreach (var file in oldBackups)
                {
                    await Task.Run(() => file.Delete());
                    _logger.LogInformation("🗑️ Eski backup silindi: {FileName} (Oluşturma tarihi: {CreationTime})",
                        file.Name, file.CreationTime);
                }

                if (oldBackups.Any())
                {
                    _logger.LogInformation("Toplam {Count} eski backup temizlendi", oldBackups.Count);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Eski backup temizleme hatası");
            }
        }
    }
}
