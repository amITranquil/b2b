using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Models;

namespace B2BApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SalesController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<SalesController> _logger;

    public SalesController(ApplicationDbContext context, ILogger<SalesController> logger)
    {
        _context = context;
        _logger = logger;
    }

    // GET: api/sales
    // Query params: ?status=pending|completed|cancelled
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Sale>>> GetSales([FromQuery] string? status = null)
    {
        try
        {
            var query = _context.Sales.Include(s => s.Items).AsQueryable();

            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(s => s.Status.ToLower() == status.ToLower());
            }

            var sales = await query
                .OrderByDescending(s => s.CreatedAt)
                .ToListAsync();

            _logger.LogInformation("Retrieved {Count} sales{StatusFilter}",
                sales.Count,
                status != null ? $" with status={status}" : "");

            return Ok(sales);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving sales");
            return StatusCode(500, new { message = "Error retrieving sales", error = ex.Message });
        }
    }

    // GET: api/sales/{id}
    [HttpGet("{id}")]
    public async Task<ActionResult<Sale>> GetSale(int id)
    {
        try
        {
            var sale = await _context.Sales
                .Include(s => s.Items)
                .FirstOrDefaultAsync(s => s.Id == id);

            if (sale == null)
            {
                _logger.LogWarning("Sale with ID {Id} not found", id);
                return NotFound(new { message = $"Sale with ID {id} not found" });
            }

            _logger.LogInformation("Retrieved sale {Id}", id);
            return Ok(sale);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving sale {Id}", id);
            return StatusCode(500, new { message = "Error retrieving sale", error = ex.Message });
        }
    }

    // POST: api/sales
    [HttpPost]
    public async Task<ActionResult<Sale>> CreateSale(Sale sale)
    {
        try
        {
            if (sale.Items == null || !sale.Items.Any())
            {
                return BadRequest(new { message = "Sale must have at least one item" });
            }

            // Set CreatedAt if not provided
            if (sale.CreatedAt == default)
            {
                sale.CreatedAt = DateTime.UtcNow;
            }

            // Validate payment method
            var validPaymentMethods = new[] { "cash", "card" };
            if (!validPaymentMethods.Contains(sale.PaymentMethod.ToLower()))
            {
                return BadRequest(new { message = "Invalid payment method. Must be 'cash' or 'card'" });
            }

            // Validate status
            var validStatuses = new[] { "pending", "completed", "cancelled" };
            if (!validStatuses.Contains(sale.Status.ToLower()))
            {
                return BadRequest(new { message = "Invalid status. Must be 'pending', 'completed', or 'cancelled'" });
            }

            _context.Sales.Add(sale);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Created sale {Id} with status {Status} and {ItemCount} items",
                sale.Id, sale.Status, sale.Items.Count);

            return CreatedAtAction(nameof(GetSale), new { id = sale.Id }, sale);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating sale");
            return StatusCode(500, new { message = "Error creating sale", error = ex.Message });
        }
    }

    // PUT: api/sales/{id}
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSale(int id, Sale sale)
    {
        if (id != sale.Id)
        {
            return BadRequest(new { message = "ID mismatch" });
        }

        try
        {
            var existingSale = await _context.Sales
                .Include(s => s.Items)
                .FirstOrDefaultAsync(s => s.Id == id);

            if (existingSale == null)
            {
                return NotFound(new { message = $"Sale with ID {id} not found" });
            }

            // Update fields
            existingSale.Status = sale.Status;
            existingSale.PaymentMethod = sale.PaymentMethod;
            existingSale.Subtotal = sale.Subtotal;
            existingSale.CardCommission = sale.CardCommission;
            existingSale.Total = sale.Total;

            // Update items if provided
            if (sale.Items != null && sale.Items.Any())
            {
                // Remove old items
                _context.SaleItems.RemoveRange(existingSale.Items);

                // Add new items
                existingSale.Items = sale.Items;
                foreach (var item in existingSale.Items)
                {
                    item.SaleId = existingSale.Id;
                }
            }

            await _context.SaveChangesAsync();

            _logger.LogInformation("Updated sale {Id} - new status: {Status}", id, sale.Status);

            return NoContent();
        }
        catch (DbUpdateConcurrencyException ex)
        {
            _logger.LogError(ex, "Concurrency error updating sale {Id}", id);
            return StatusCode(409, new { message = "Sale was modified by another user" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating sale {Id}", id);
            return StatusCode(500, new { message = "Error updating sale", error = ex.Message });
        }
    }

    // DELETE: api/sales/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteSale(int id)
    {
        try
        {
            var sale = await _context.Sales.FindAsync(id);
            if (sale == null)
            {
                return NotFound(new { message = $"Sale with ID {id} not found" });
            }

            _context.Sales.Remove(sale);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Deleted sale {Id}", id);

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting sale {Id}", id);
            return StatusCode(500, new { message = "Error deleting sale", error = ex.Message });
        }
    }

    // PATCH: api/sales/{id}/status
    // Quick endpoint to just update status
    [HttpPatch("{id}/status")]
    public async Task<IActionResult> UpdateSaleStatus(int id, [FromBody] StatusUpdateRequest request)
    {
        try
        {
            var sale = await _context.Sales.FindAsync(id);
            if (sale == null)
            {
                return NotFound(new { message = $"Sale with ID {id} not found" });
            }

            var validStatuses = new[] { "pending", "completed", "cancelled" };
            if (!validStatuses.Contains(request.Status.ToLower()))
            {
                return BadRequest(new { message = "Invalid status. Must be 'pending', 'completed', or 'cancelled'" });
            }

            sale.Status = request.Status.ToLower();
            await _context.SaveChangesAsync();

            _logger.LogInformation("Updated sale {Id} status to {Status}", id, sale.Status);

            return Ok(sale);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating sale {Id} status", id);
            return StatusCode(500, new { message = "Error updating sale status", error = ex.Message });
        }
    }
}

public class StatusUpdateRequest
{
    public string Status { get; set; } = string.Empty;
}
