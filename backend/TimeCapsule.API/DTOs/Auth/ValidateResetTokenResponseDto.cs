namespace TimeCapsule.API.DTOs.Auth;
public class ValidateResetTokenResponseDto
{
    public bool IsValid { get; set; }
    public string? Email { get; set; }
}
