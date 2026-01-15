using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Models;

namespace B2BApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class QuotesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<QuotesController> _logger;

        public QuotesController(ApplicationDbContext context, ILogger<QuotesController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // Helper method to get Istanbul time (UTC+3)
        private static DateTime GetIstanbulTime()
        {
            TimeZoneInfo istanbulTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, istanbulTimeZone);
        }

        // GET: api/quotes
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Quote>>> GetQuotes()
        {
            try
            {
                var quotes = await _context.Quotes
                    .Include(q => q.Items)
                    .OrderByDescending(q => q.CreatedAt)
                    .ToListAsync();

                return Ok(quotes);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting quotes");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/quotes/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<Quote>> GetQuote(int id)
        {
            try
            {
                var quote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == id);

                if (quote == null)
                {
                    return NotFound($"Quote with id {id} not found");
                }

                return Ok(quote);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting quote: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // POST: api/quotes
        [HttpPost]
        public async Task<ActionResult<Quote>> CreateQuote([FromBody] Quote quote)
        {
            try
            {
                if (quote == null)
                {
                    return BadRequest("Quote data is required");
                }

                // Reset IDs for new quote (database will generate them)
                quote.Id = 0;
                foreach (var item in quote.Items)
                {
                    item.Id = 0;
                    item.QuoteId = 0;
                }

                // Set creation time (Istanbul timezone)
                quote.CreatedAt = GetIstanbulTime();
                quote.ModifiedAt = null;

                // Calculate totals
                quote.TotalAmount = quote.Items.Sum(item => item.Total);
                quote.VatAmount = quote.TotalAmount * 0.20; // %20 KDV

                _context.Quotes.Add(quote);
                await _context.SaveChangesAsync();

                // Reload to get generated IDs
                var createdQuote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == quote.Id);

                _logger.LogInformation($"Created new quote: {quote.Id}");
                return CreatedAtAction(nameof(GetQuote), new { id = quote.Id }, createdQuote);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating quote");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/quotes/{id}
        [HttpPut("{id}")]
        public async Task<ActionResult<Quote>> UpdateQuote(int id, [FromBody] Quote quote)
        {
            try
            {
                if (id != quote.Id)
                {
                    return BadRequest("Quote ID mismatch");
                }

                var existingQuote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == id);

                if (existingQuote == null)
                {
                    return NotFound($"Quote with id {id} not found");
                }

                // Update quote properties
                existingQuote.CustomerName = quote.CustomerName;
                existingQuote.Representative = quote.Representative;
                existingQuote.PaymentTerm = quote.PaymentTerm;
                existingQuote.Phone = quote.Phone;
                existingQuote.Note = quote.Note;
                existingQuote.ExtraNote = quote.ExtraNote;
                existingQuote.IsDraft = quote.IsDraft;
                existingQuote.ModifiedAt = GetIstanbulTime();

                // Remove old items
                _context.QuoteItems.RemoveRange(existingQuote.Items);

                // Add new items (reset IDs to let database generate them)
                existingQuote.Items = quote.Items.Select(item => new QuoteItem
                {
                    Id = 0, // Let database generate new ID
                    QuoteId = id,
                    Description = item.Description,
                    Quantity = item.Quantity,
                    Unit = item.Unit,
                    Price = item.Price,
                    VatRate = item.VatRate,
                    MarginPercentage = item.MarginPercentage
                }).ToList();

                // Recalculate totals
                existingQuote.TotalAmount = existingQuote.Items.Sum(item => item.Total);
                existingQuote.VatAmount = existingQuote.TotalAmount * 0.20;

                await _context.SaveChangesAsync();

                // Reload to get updated data
                var updatedQuote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == id);

                _logger.LogInformation($"Updated quote: {id}");
                return Ok(updatedQuote);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating quote: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // DELETE: api/quotes/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteQuote(int id)
        {
            try
            {
                var quote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == id);

                if (quote == null)
                {
                    return NotFound($"Quote with id {id} not found");
                }

                _context.Quotes.Remove(quote);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Deleted quote: {id}");
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting quote: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/quotes/customer/{customerName}
        [HttpGet("customer/{customerName}")]
        public async Task<ActionResult<IEnumerable<Quote>>> GetQuotesByCustomer(string customerName)
        {
            try
            {
                var quotes = await _context.Quotes
                    .Include(q => q.Items)
                    .Where(q => q.CustomerName.Contains(customerName))
                    .OrderByDescending(q => q.CreatedAt)
                    .ToListAsync();

                return Ok(quotes);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting quotes for customer: {customerName}");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/quotes/{id}/toggle-draft
        [HttpPut("{id}/toggle-draft")]
        public async Task<ActionResult<Quote>> ToggleDraftStatus(int id)
        {
            try
            {
                var quote = await _context.Quotes
                    .Include(q => q.Items)
                    .FirstOrDefaultAsync(q => q.Id == id);

                if (quote == null)
                {
                    return NotFound($"Quote with id {id} not found");
                }

                // Toggle draft status
                quote.IsDraft = !quote.IsDraft;
                quote.ModifiedAt = GetIstanbulTime();

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Toggled draft status for quote {id}: isDraft={quote.IsDraft}");
                return Ok(quote);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error toggling draft status for quote: {id}");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
