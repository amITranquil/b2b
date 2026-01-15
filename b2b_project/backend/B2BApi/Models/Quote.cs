using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace B2BApi.Models
{
    public class Quote
    {
        // Helper method to get Istanbul time (UTC+3)
        private static DateTime GetIstanbulTime()
        {
            TimeZoneInfo istanbulTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, istanbulTimeZone);
        }

        public int Id { get; set; }

        [Required]
        [StringLength(200)]
        public string CustomerName { get; set; } = string.Empty;

        [StringLength(200)]
        public string Representative { get; set; } = string.Empty;

        [StringLength(100)]
        public string PaymentTerm { get; set; } = string.Empty;

        [StringLength(50)]
        public string Phone { get; set; } = string.Empty;

        [StringLength(1000)]
        public string Note { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? ExtraNote { get; set; }

        [Required]
        public DateTime CreatedAt { get; set; } = GetIstanbulTime();

        public DateTime? ModifiedAt { get; set; }

        public double TotalAmount { get; set; } = 0;

        public double VatAmount { get; set; } = 0;

        public bool IsDraft { get; set; } = false;

        // Navigation property
        public ICollection<QuoteItem> Items { get; set; } = new List<QuoteItem>();
    }

    public class QuoteItem
    {
        public int Id { get; set; }

        [Required]
        public int QuoteId { get; set; }

        [Required]
        [StringLength(500)]
        public string Description { get; set; } = string.Empty;

        [Required]
        public double Quantity { get; set; }

        [Required]
        [StringLength(50)]
        public string Unit { get; set; } = string.Empty;

        [Required]
        public double Price { get; set; }

        public double VatRate { get; set; } = 20; // KDV oranı, varsayılan %20

        public double MarginPercentage { get; set; } = 40; // Kar marjı oranı, varsayılan %40

        // Navigation property (JSON'dan hariç tut - circular reference önlemek için)
        [JsonIgnore]
        public Quote? Quote { get; set; }

        // Calculated property
        public double Total => Quantity * Price;
    }
}
