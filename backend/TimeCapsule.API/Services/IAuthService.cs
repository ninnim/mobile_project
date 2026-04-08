using TimeCapsule.API.DTOs.Auth;

namespace TimeCapsule.API.Services;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterDto dto);
    Task<AuthResponseDto> LoginAsync(LoginDto dto);
    Task<UserProfileDto> GetCurrentUserAsync(Guid userId);
    Task<UserDto> UpdateProfileAsync(Guid userId, UpdateProfileDto dto, IFormFile? profilePicture);
    Task<AuthResponseDto> LoginWithGoogleAsync(string googleToken, bool isIdToken = false);
    Task<AuthResponseDto> LoginWithFacebookAsync(string facebookAccessToken);
    Task ForgotPasswordAsync(string email);
    Task<ValidateResetTokenResponseDto> ValidateResetTokenAsync(string token);
    Task<bool> ResetPasswordAsync(string token, string newPassword);
    Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword);
}
