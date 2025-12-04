using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Services;

namespace B2BApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly ILogger<AuthController> _logger;
        private readonly ApplicationDbContext _context;
        private readonly JwtService _jwtService;

        public AuthController(ILogger<AuthController> logger, ApplicationDbContext context, JwtService jwtService)
        {
            _logger = logger;
            _context = context;
            _jwtService = jwtService;
        }

        /// <summary>
        /// Database'den ayar değerini getir
        /// </summary>
        private async Task<string?> GetSettingAsync(string key)
        {
            var setting = await _context.AppSettings
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.Key == key);
            return setting?.Value;
        }

        /// <summary>
        /// Database'de ayar değerini güncelle
        /// </summary>
        private async Task<bool> UpdateSettingAsync(string key, string value, string? updatedBy = null)
        {
            var setting = await _context.AppSettings.FirstOrDefaultAsync(s => s.Key == key);
            if (setting != null)
            {
                setting.Value = value;
                setting.LastUpdated = DateTime.UtcNow;
                setting.UpdatedBy = updatedBy;
                await _context.SaveChangesAsync();
                return true;
            }
            return false;
        }

        /// <summary>
        /// JWT token ile login - PIN doğrulama yapıp JWT döner
        /// </summary>
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] PinRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Pin))
                {
                    return BadRequest(new { success = false, message = "PIN boş olamaz" });
                }

                // Database'den PIN'i al
                var catalogPin = await GetSettingAsync("CatalogPin");
                if (catalogPin == null)
                {
                    _logger.LogError("CatalogPin ayarı database'de bulunamadı!");
                    return StatusCode(500, new { success = false, message = "Sistem ayarı bulunamadı" });
                }

                // PIN kontrolü
                if (request.Pin == catalogPin)
                {
                    // JWT token oluştur
                    var token = _jwtService.GenerateToken("catalog_user", "CatalogViewer");

                    _logger.LogInformation("PIN doğrulandı, JWT token oluşturuldu");

                    return Ok(new
                    {
                        success = true,
                        token = token,
                        message = "Giriş başarılı",
                        expiresIn = 3600 // 1 saat (saniye cinsinden)
                    });
                }

                _logger.LogWarning("Hatalı PIN girişi yapıldı");
                return Unauthorized(new { success = false, message = "Hatalı PIN" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Login hatası");
                return StatusCode(500, new { success = false, message = "Sunucu hatası" });
            }
        }

        /// <summary>
        /// Eski verify-pin endpoint (geriye uyumluluk için)
        /// </summary>
        [HttpPost("verify-pin")]
        public async Task<IActionResult> VerifyPin([FromBody] PinRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Pin))
                {
                    return BadRequest(new { valid = false, message = "PIN boş olamaz" });
                }

                // Database'den PIN'i al
                var catalogPin = await GetSettingAsync("CatalogPin");
                if (catalogPin == null)
                {
                    _logger.LogError("CatalogPin ayarı database'de bulunamadı!");
                    return StatusCode(500, new { valid = false, message = "Sistem ayarı bulunamadı" });
                }

                // PIN kontrolü
                if (request.Pin == catalogPin)
                {
                    // Session süresi database'den al
                    var sessionDurationStr = await GetSettingAsync("SessionDurationHours");
                    var sessionDuration = int.TryParse(sessionDurationStr, out var hours) ? hours : 1;

                    var sessionToken = Guid.NewGuid().ToString();
                    var expiresAt = DateTime.UtcNow.AddHours(sessionDuration);

                    // Session cookie set et
                    Response.Cookies.Append("catalog_session", sessionToken, new CookieOptions
                    {
                        HttpOnly = true,
                        Secure = false, // HTTPS için true yapılmalı
                        SameSite = SameSiteMode.Strict,
                        Expires = expiresAt
                    });

                    _logger.LogInformation("PIN doğrulandı. Session: {SessionToken}, Süre: {Hours} saat",
                        sessionToken, sessionDuration);

                    return Ok(new
                    {
                        valid = true,
                        message = "PIN doğrulandı",
                        expiresAt = expiresAt
                    });
                }

                _logger.LogWarning("Hatalı PIN girişi yapıldı. Girilen: {Pin}", request.Pin);
                return Ok(new { valid = false, message = "Hatalı PIN" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PIN doğrulama hatası");
                return StatusCode(500, new { valid = false, message = "Sunucu hatası" });
            }
        }

        [HttpPost("check-session")]
        public IActionResult CheckSession()
        {
            try
            {
                if (Request.Cookies.TryGetValue("catalog_session", out var sessionToken)
                    && !string.IsNullOrEmpty(sessionToken))
                {
                    return Ok(new { authenticated = true });
                }

                return Ok(new { authenticated = false });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Session kontrol hatası");
                return StatusCode(500, new { message = "Sunucu hatası" });
            }
        }

        [HttpPost("logout")]
        public IActionResult Logout()
        {
            try
            {
                Response.Cookies.Delete("catalog_session");
                _logger.LogInformation("Kullanıcı çıkış yaptı");
                return Ok(new { success = true, message = "Çıkış yapıldı" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Logout hatası");
                return StatusCode(500, new { message = "Sunucu hatası" });
            }
        }

        /// <summary>
        /// PIN kodunu güncelle (admin işlemi)
        /// </summary>
        [HttpPost("update-pin")]
        public async Task<IActionResult> UpdatePin([FromBody] UpdatePinRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.CurrentPin))
                {
                    return BadRequest(new { success = false, message = "Mevcut PIN boş olamaz" });
                }

                if (string.IsNullOrWhiteSpace(request.NewPin))
                {
                    return BadRequest(new { success = false, message = "Yeni PIN boş olamaz" });
                }

                if (request.NewPin.Length < 4)
                {
                    return BadRequest(new { success = false, message = "PIN en az 4 karakter olmalıdır" });
                }

                // Mevcut PIN'i kontrol et
                var currentPin = await GetSettingAsync("CatalogPin");
                if (currentPin == null || request.CurrentPin != currentPin)
                {
                    _logger.LogWarning("PIN güncelleme başarısız - hatalı mevcut PIN");
                    return Unauthorized(new { success = false, message = "Mevcut PIN hatalı" });
                }

                // Yeni PIN'i kaydet
                var updated = await UpdateSettingAsync("CatalogPin", request.NewPin, request.UpdatedBy);

                if (updated)
                {
                    _logger.LogInformation("PIN başarıyla güncellendi. Güncelleyen: {UpdatedBy}",
                        request.UpdatedBy ?? "Bilinmeyen");

                    return Ok(new { success = true, message = "PIN başarıyla güncellendi" });
                }

                return StatusCode(500, new { success = false, message = "PIN güncellenemedi" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PIN güncelleme hatası");
                return StatusCode(500, new { success = false, message = "Sunucu hatası" });
            }
        }

        /// <summary>
        /// Mevcut PIN'i getir (sadece backend'de kullanılacak - güvenlik için)
        /// </summary>
        [HttpGet("get-current-pin-masked")]
        public async Task<IActionResult> GetCurrentPinMasked()
        {
            try
            {
                var pin = await GetSettingAsync("CatalogPin");
                if (pin == null)
                {
                    return NotFound(new { message = "PIN bulunamadı" });
                }

                // PIN'i maskele (güvenlik için tam değeri gösterme)
                var maskedPin = pin.Length > 2
                    ? pin.Substring(0, 1) + new string('*', pin.Length - 2) + pin.Substring(pin.Length - 1)
                    : new string('*', pin.Length);

                return Ok(new
                {
                    length = pin.Length,
                    masked = maskedPin,
                    message = "PIN bilgisi"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PIN bilgisi getirme hatası");
                return StatusCode(500, new { message = "Sunucu hatası" });
            }
        }
    }

    public class PinRequest
    {
        public string Pin { get; set; } = string.Empty;
    }

    public class UpdatePinRequest
    {
        public string CurrentPin { get; set; } = string.Empty;
        public string NewPin { get; set; } = string.Empty;
        public string? UpdatedBy { get; set; }
    }
}
