namespace B2BApi.Models
{
    /// <summary>
    /// Unified product model for combining Products and ManualProducts
    /// </summary>
    public class UnifiedProduct
    {
        public int Id { get; set; }
        public string ProductCode { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public decimal MyPrice { get; set; } = 0; // Final sale price with VAT
        public decimal SalePriceExcludingVat { get; set; } = 0;
        public decimal SalePriceIncludingVat { get; set; } = 0;
        public decimal MarginPercentage { get; set; } = 0; // Kar marjı (%)
        public decimal VatRate { get; set; } = 0; // KDV oranı
        public DateTime LastUpdated { get; set; }
        public bool IsManual { get; set; } // True = Manual, False = API Product
        public bool IsDeleted { get; set; } = false;

        // Optional fields (only for API products)
        public decimal? ListPrice { get; set; }
        public decimal? BuyPriceExcludingVat { get; set; }
        public decimal? BuyPriceIncludingVat { get; set; }
        public decimal? Discount1 { get; set; }
        public decimal? Discount2 { get; set; }
        public decimal? Discount3 { get; set; }
        public string? ImageUrl { get; set; }
        public string? LocalImagePath { get; set; }

        // Optional fields (only for manual products)
        public decimal? BuyPrice { get; set; } // Alış fiyatı (manual products)
        public DateTime? CreatedAt { get; set; }
    }
}
