using System.ComponentModel.DataAnnotations;

namespace B2BApi.Models
{
    public class ManualProduct
    {
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        public string ProductCode { get; set; } = Guid.NewGuid().ToString();

        [Required]
        [StringLength(500)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public decimal BuyPrice { get; set; } = 0; // Alış Fiyatı (KDV Hariç)

        [Required]
        public decimal ProfitMargin { get; set; } = 40M; // Kar Marjı (Default %40)

        [Required]
        public decimal VatRate { get; set; } = 20M; // KDV Oranı (Default %20, seçenekler: 10 veya 20)

        [Required]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

        // Hesaplanmış özellikler (JSON'a dahil edilecek)
        // Satış Fiyatı (KDV Hariç) = Alış Fiyatı * (1 + Kar Marjı/100)
        public decimal SalePriceExcludingVat => BuyPrice * (1 + ProfitMargin / 100);

        // Satış Fiyatı (KDV Dahil) = Satış Fiyatı (KDV Hariç) * (1 + KDV/100)
        public decimal SalePriceIncludingVat => SalePriceExcludingVat * (1 + VatRate / 100);

        // MyPrice (Product ile uyumlu olması için)
        public decimal MyPrice => SalePriceIncludingVat;

        // Soft Delete
        public bool IsDeleted { get; set; } = false;

        public DateTime? DeletedAt { get; set; }
    }
}
