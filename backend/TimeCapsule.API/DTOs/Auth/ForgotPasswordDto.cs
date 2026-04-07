using System.ComponentModel.DataAnnotations;
namespace TimeCapsule.API.DTOs.Auth;
public class ForgotPasswordDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = "";
}
