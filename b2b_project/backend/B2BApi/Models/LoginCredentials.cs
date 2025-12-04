using System.ComponentModel.DataAnnotations;

namespace B2BApi.Models
{
    public class LoginCredentials
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;
        
        [Required]
        public string Password { get; set; } = string.Empty;
    }
}