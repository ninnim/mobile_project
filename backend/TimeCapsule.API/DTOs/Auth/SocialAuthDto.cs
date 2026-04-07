using System.ComponentModel.DataAnnotations;
namespace TimeCapsule.API.DTOs.Auth;
public class SocialAuthDto
{
    [Required]
    public string AccessToken { get; set; } = "";
    public bool IsIdToken { get; set; } = false;
}
