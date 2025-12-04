using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace B2BApi.Migrations
{
    /// <inheritdoc />
    public partial class AddMarginPercentageToQuoteItem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "MarginPercentage",
                table: "QuoteItems",
                type: "REAL",
                nullable: false,
                defaultValue: 0.0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MarginPercentage",
                table: "QuoteItems");
        }
    }
}
