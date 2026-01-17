using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace B2BApi.Models;

public class Sale
{
    [Key]
    public int Id { get; set; }

    [Required]
    public DateTime CreatedAt { get; set; }

    public List<SaleItem> Items { get; set; } = new();

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Subtotal { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal CardCommission { get; set; }

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Total { get; set; }

    [Required]
    [MaxLength(50)]
    public string PaymentMethod { get; set; } = "cash"; // cash, card

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "completed"; // pending, completed, cancelled
}

public class SaleItem
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int SaleId { get; set; }

    [ForeignKey("SaleId")]
    [JsonIgnore]
    public Sale? Sale { get; set; }

    [Required]
    [MaxLength(100)]
    public string ProductCode { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    public string ProductName { get; set; } = string.Empty;

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Quantity { get; set; }

    [Required]
    [MaxLength(50)]
    public string Unit { get; set; } = "Adet";

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Price { get; set; }

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal VatRate { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal Total => Quantity * Price;

    [Column(TypeName = "decimal(18,2)")]
    public decimal VatAmount => Total - (Total / (1 + VatRate / 100));
}
