using System.ComponentModel.DataAnnotations;

namespace B2BApi.Models
{
    public class Product
    {
        public int Id { get; set; }
        
        [Required]
        [StringLength(50)]
        public string ProductCode { get; set; } = string.Empty;
        
        [Required]
        [StringLength(500)]
        public string Name { get; set; } = string.Empty;
        
        // Fiyat Bilgileri
        public decimal ListPrice { get; set; } = 0; // Liste Fiyatı
        
        [Required]
        public decimal BuyPriceExcludingVat { get; set; } = 0; // KDV Hariç Alış Fiyatı
        
        [Required]
        public decimal BuyPriceIncludingVat { get; set; } = 0; // KDV Dahil Alış Fiyatı
        
        [Required]
        public decimal MyPrice { get; set; } = 0; // Kar marjı eklenmiş satış fiyatımız (KDV Dahil)

        // Hesaplanmış satış fiyatları (JSON'a dahil edilecek)
        public decimal SalePriceExcludingVat => VatRate > 0 ? MyPrice / (1 + VatRate / 100) : MyPrice;
        public decimal SalePriceIncludingVat => MyPrice;

        // İskonto Bilgileri
        public decimal Discount1 { get; set; } = 0;
        public decimal Discount2 { get; set; } = 0;
        public decimal Discount3 { get; set; } = 0;
        
        // KDV Bilgisi
        public decimal VatRate { get; set; } = 0; // KDV Oranı
        
        // Resim Bilgileri
        [StringLength(500)]
        public string? ImageUrl { get; set; } // Orijinal resim URL'i
        
        [StringLength(200)]
        public string? LocalImagePath { get; set; } // Lokal resim path'i
        
        [Required]
        public decimal MarginPercentage { get; set; } = 40;
        
        [Required]
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

        // Soft Delete için
        public bool IsDeleted { get; set; } = false;

        public DateTime? DeletedAt { get; set; }

        // Backward compatibility için eski alanları kaldırdık
        // BuyPrice -> BuyPriceExcludingVat
        // Stock -> artık kullanmıyoruz
        // Category -> artık kullanmıyoruz
    }
}