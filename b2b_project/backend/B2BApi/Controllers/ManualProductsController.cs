using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Models;

namespace B2BApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ManualProductsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<ManualProductsController> _logger;

        public ManualProductsController(ApplicationDbContext context, ILogger<ManualProductsController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // GET: api/manualproducts
        [HttpGet]
        public async Task<ActionResult<IEnumerable<ManualProduct>>> GetManualProducts([FromQuery] bool includeDeleted = false)
        {
            try
            {
                var query = _context.ManualProducts.AsQueryable();

                if (!includeDeleted)
                {
                    query = query.Where(p => !p.IsDeleted);
                }

                var products = await query
                    .OrderByDescending(p => p.CreatedAt)
                    .ToListAsync();

                return Ok(products);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting manual products");
                return StatusCode(500, "Internal server error");
            }
        }

        // GET: api/manualproducts/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<ManualProduct>> GetManualProduct(int id)
        {
            try
            {
                var product = await _context.ManualProducts
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (product == null)
                {
                    return NotFound($"Manual product with ID {id} not found");
                }

                return Ok(product);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting manual product with ID: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // POST: api/manualproducts
        [HttpPost]
        public async Task<ActionResult<ManualProduct>> CreateManualProduct([FromBody] ManualProduct product)
        {
            try
            {
                // GUID ile product code oluştur
                product.ProductCode = Guid.NewGuid().ToString();
                product.CreatedAt = DateTime.UtcNow;
                product.LastUpdated = DateTime.UtcNow;

                // Validation
                if (string.IsNullOrWhiteSpace(product.Name))
                {
                    return BadRequest("Product name is required");
                }

                if (product.BuyPrice <= 0)
                {
                    return BadRequest("Buy price must be greater than 0");
                }

                if (product.ProfitMargin < 0 || product.ProfitMargin > 1000)
                {
                    return BadRequest("Profit margin must be between 0 and 1000");
                }

                if (product.VatRate != 10 && product.VatRate != 20)
                {
                    return BadRequest("VAT rate must be either 10 or 20");
                }

                // Duplicate check - Products tablosunda aynı isimli ürün var mı?
                // Turkish character desteği için client-side karşılaştırma yapıyoruz
                var trimmedName = product.Name.Trim();
                var normalizedSearchName = trimmedName.ToLowerInvariant();

                var allApiProducts = await _context.Products
                    .Where(p => !p.IsDeleted)
                    .ToListAsync();

                var existingApiProduct = allApiProducts
                    .FirstOrDefault(p => p.Name.Trim().ToLowerInvariant() == normalizedSearchName);

                if (existingApiProduct != null)
                {
                    _logger.LogWarning($"Duplicate product name attempt: {product.Name} (exists in Products table)");
                    return Conflict(new
                    {
                        message = "Bu isimde bir ürün zaten mevcut (API ürünleri)",
                        existingProduct = new
                        {
                            existingApiProduct.Id,
                            existingApiProduct.ProductCode,
                            existingApiProduct.Name,
                            IsManual = false
                        }
                    });
                }

                // Duplicate check - ManualProducts tablosunda aynı isimli ürün var mı?
                var allManualProducts = await _context.ManualProducts
                    .Where(p => !p.IsDeleted)
                    .ToListAsync();

                var existingManualProduct = allManualProducts
                    .FirstOrDefault(p => p.Name.Trim().ToLowerInvariant() == normalizedSearchName);

                if (existingManualProduct != null)
                {
                    _logger.LogWarning($"Duplicate product name attempt: {product.Name} (exists in ManualProducts table)");
                    return Conflict(new
                    {
                        message = "Bu isimde bir manuel ürün zaten mevcut",
                        existingProduct = new
                        {
                            existingManualProduct.Id,
                            existingManualProduct.ProductCode,
                            existingManualProduct.Name,
                            IsManual = true
                        }
                    });
                }

                _context.ManualProducts.Add(product);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Manual product created: {product.Name} (ID: {product.Id})");

                return CreatedAtAction(nameof(GetManualProduct), new { id = product.Id }, product);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating manual product");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/manualproducts/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateManualProduct(int id, [FromBody] ManualProduct product)
        {
            try
            {
                if (id != product.Id)
                {
                    return BadRequest("ID mismatch");
                }

                var existingProduct = await _context.ManualProducts
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (existingProduct == null)
                {
                    return NotFound($"Manual product with ID {id} not found");
                }

                // Validation
                if (string.IsNullOrWhiteSpace(product.Name))
                {
                    return BadRequest("Product name is required");
                }

                if (product.BuyPrice <= 0)
                {
                    return BadRequest("Buy price must be greater than 0");
                }

                if (product.ProfitMargin < 0 || product.ProfitMargin > 1000)
                {
                    return BadRequest("Profit margin must be between 0 and 1000");
                }

                if (product.VatRate != 10 && product.VatRate != 20)
                {
                    return BadRequest("VAT rate must be either 10 or 20");
                }

                // Duplicate check - Products tablosunda aynı isimli başka bir ürün var mı?
                // Turkish character desteği için client-side karşılaştırma yapıyoruz
                var trimmedName = product.Name.Trim();
                var normalizedSearchName = trimmedName.ToLowerInvariant();

                var allApiProducts = await _context.Products
                    .Where(p => !p.IsDeleted)
                    .ToListAsync();

                var duplicateApiProduct = allApiProducts
                    .FirstOrDefault(p => p.Name.Trim().ToLowerInvariant() == normalizedSearchName);

                if (duplicateApiProduct != null)
                {
                    _logger.LogWarning($"Duplicate product name in update: {product.Name} (exists in Products table)");
                    return Conflict(new
                    {
                        message = "Bu isimde bir ürün zaten mevcut (API ürünleri)",
                        existingProduct = new
                        {
                            duplicateApiProduct.Id,
                            duplicateApiProduct.ProductCode,
                            duplicateApiProduct.Name,
                            IsManual = false
                        }
                    });
                }

                // Duplicate check - ManualProducts tablosunda aynı isimli BAŞKA bir ürün var mı? (kendi ID'si hariç)
                var allManualProducts = await _context.ManualProducts
                    .Where(p => !p.IsDeleted && p.Id != id)
                    .ToListAsync();

                var duplicateManualProduct = allManualProducts
                    .FirstOrDefault(p => p.Name.Trim().ToLowerInvariant() == normalizedSearchName);

                if (duplicateManualProduct != null)
                {
                    _logger.LogWarning($"Duplicate product name in update: {product.Name} (exists in ManualProducts table)");
                    return Conflict(new
                    {
                        message = "Bu isimde bir manuel ürün zaten mevcut",
                        existingProduct = new
                        {
                            duplicateManualProduct.Id,
                            duplicateManualProduct.ProductCode,
                            duplicateManualProduct.Name,
                            IsManual = true
                        }
                    });
                }

                // Update fields
                existingProduct.Name = product.Name;
                existingProduct.BuyPrice = product.BuyPrice;
                existingProduct.ProfitMargin = product.ProfitMargin;
                existingProduct.VatRate = product.VatRate;
                existingProduct.LastUpdated = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Manual product updated: {existingProduct.Name} (ID: {id})");

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating manual product with ID: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/manualproducts/{id}/margin
        [HttpPut("{id}/margin")]
        public async Task<IActionResult> UpdateMargin(int id, [FromBody] decimal profitMargin)
        {
            try
            {
                if (profitMargin < 0 || profitMargin > 1000)
                {
                    return BadRequest("Profit margin must be between 0 and 1000");
                }

                var product = await _context.ManualProducts
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (product == null)
                {
                    return NotFound($"Manual product with ID {id} not found");
                }

                product.ProfitMargin = profitMargin;
                product.LastUpdated = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Manual product margin updated: {product.Name} (ID: {id}, Margin: {profitMargin}%)");

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating margin for manual product with ID: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // DELETE: api/manualproducts/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteManualProduct(int id)
        {
            try
            {
                var product = await _context.ManualProducts
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (product == null)
                {
                    return NotFound($"Manual product with ID {id} not found");
                }

                // Soft delete
                product.IsDeleted = true;
                product.DeletedAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Manual product soft deleted: {product.Name} (ID: {id})");

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting manual product with ID: {id}");
                return StatusCode(500, "Internal server error");
            }
        }

        // PUT: api/manualproducts/{id}/restore
        [HttpPut("{id}/restore")]
        public async Task<IActionResult> RestoreManualProduct(int id)
        {
            try
            {
                var product = await _context.ManualProducts
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (product == null)
                {
                    return NotFound($"Manual product with ID {id} not found");
                }

                product.IsDeleted = false;
                product.DeletedAt = null;
                product.LastUpdated = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Manual product restored: {product.Name} (ID: {id})");

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error restoring manual product with ID: {id}");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
