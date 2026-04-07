using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Auth;

public class RegisterDto
{
    [Required, EmailAddress, MaxLength(255)]
    public string Email { get; set; } = string.Empty;
    [Required, MinLength(6), MaxLength(100)]
    public string Password { get; set; } = string.Empty;
    [Required, MinLength(2), MaxLength(100)]
    public string DisplayName { get; set; } = string.Empty;
}
