using System.ComponentModel.DataAnnotations;

namespace B2BApi.Models
{
    /// <summary>
    /// Uygulama ayarlarını database'de tutar
    /// </summary>
    public class AppSetting
    {
        [Key]
        public int Id { get; set; }

        /// <summary>
        /// Ayar anahtarı (örn: "CatalogPin", "SessionDurationHours")
        /// </summary>
        [Required]
        [MaxLength(100)]
        public string Key { get; set; } = string.Empty;

        /// <summary>
        /// Ayar değeri
        /// </summary>
        [Required]
        [MaxLength(500)]
        public string Value { get; set; } = string.Empty;

        /// <summary>
        /// Ayar açıklaması
        /// </summary>
        [MaxLength(1000)]
        public string? Description { get; set; }

        /// <summary>
        /// Son güncelleme zamanı
        /// </summary>
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Güncelleyen kullanıcı
        /// </summary>
        [MaxLength(100)]
        public string? UpdatedBy { get; set; }
    }
}
