using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Auth;

public class ChangePasswordDto
{
    [Required]
    public string CurrentPassword { get; set; } = "";

    [Required, MinLength(6), MaxLength(100)]
    public string NewPassword { get; set; } = "";
}
