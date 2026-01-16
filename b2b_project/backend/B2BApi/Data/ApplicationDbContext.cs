using Microsoft.EntityFrameworkCore;
using B2BApi.Models;

namespace B2BApi.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
        {
        }

        public DbSet<Product> Products { get; set; }
        public DbSet<ManualProduct> ManualProducts { get; set; }
        public DbSet<Quote> Quotes { get; set; }
        public DbSet<QuoteItem> QuoteItems { get; set; }
        public DbSet<AppSetting> AppSettings { get; set; }
        public DbSet<Sale> Sales { get; set; }
        public DbSet<SaleItem> SaleItems { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Product>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasIndex(e => e.ProductCode).IsUnique();

                // Fiyat alanları
                entity.Property(e => e.ListPrice).HasColumnType("decimal(18,2)");
                entity.Property(e => e.BuyPriceExcludingVat).HasColumnType("decimal(18,2)");
                entity.Property(e => e.BuyPriceIncludingVat).HasColumnType("decimal(18,2)");
                entity.Property(e => e.MyPrice).HasColumnType("decimal(18,2)");

                // İskonto ve KDV alanları
                entity.Property(e => e.Discount1).HasColumnType("decimal(5,2)");
                entity.Property(e => e.Discount2).HasColumnType("decimal(5,2)");
                entity.Property(e => e.Discount3).HasColumnType("decimal(5,2)");
                entity.Property(e => e.VatRate).HasColumnType("decimal(5,2)");
                entity.Property(e => e.MarginPercentage).HasColumnType("decimal(5,2)");
            });

            modelBuilder.Entity<ManualProduct>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasIndex(e => e.ProductCode).IsUnique();

                // Fiyat alanları
                entity.Property(e => e.BuyPrice).HasColumnType("decimal(18,2)");
                entity.Property(e => e.ProfitMargin).HasColumnType("decimal(5,2)");
                entity.Property(e => e.VatRate).HasColumnType("decimal(5,2)");
            });

            modelBuilder.Entity<Quote>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.Property(e => e.TotalAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.VatAmount).HasColumnType("decimal(18,2)");

                // One-to-many relationship
                entity.HasMany(e => e.Items)
                      .WithOne(e => e.Quote)
                      .HasForeignKey(e => e.QuoteId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<QuoteItem>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Quantity).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Price).HasColumnType("decimal(18,2)");
            });

            modelBuilder.Entity<AppSetting>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasIndex(e => e.Key).IsUnique();

                // Seed initial data
                entity.HasData(
                    new AppSetting
                    {
                        Id = 1,
                        Key = "CatalogPin",
                        Value = "1234",
                        Description = "Katalog detay görüntüleme PIN kodu",
                        LastUpdated = new DateTime(2024, 11, 10, 12, 0, 0, DateTimeKind.Utc)
                    },
                    new AppSetting
                    {
                        Id = 2,
                        Key = "SessionDurationHours",
                        Value = "1",
                        Description = "Oturum süresi (saat)",
                        LastUpdated = new DateTime(2024, 11, 10, 12, 0, 0, DateTimeKind.Utc)
                    }
                );
            });

            modelBuilder.Entity<Sale>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Subtotal).HasColumnType("decimal(18,2)");
                entity.Property(e => e.CardCommission).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Total).HasColumnType("decimal(18,2)");

                // One-to-many relationship
                entity.HasMany(e => e.Items)
                      .WithOne(e => e.Sale)
                      .HasForeignKey(e => e.SaleId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<SaleItem>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.Property(e => e.Quantity).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Price).HasColumnType("decimal(18,2)");
                entity.Property(e => e.VatRate).HasColumnType("decimal(18,2)");
            });

            base.OnModelCreating(modelBuilder);
        }
    }
}