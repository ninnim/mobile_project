using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Auth;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly ILogger<AuthController> _logger;
    private readonly AppDbContext _db;

    public AuthController(IAuthService auth, ILogger<AuthController> logger, AppDbContext db)
    {
        _auth = auth;
        _logger = logger;
        _db = db;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        try { return StatusCode(201, await _auth.RegisterAsync(dto)); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        try { return Ok(await _auth.LoginAsync(dto)); }
        catch (UnauthorizedAccessException ex) { return Unauthorized(new { error = ex.Message }); }
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try { return Ok(await _auth.GetCurrentUserAsync(userId)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [Authorize]
    [HttpPut("me")]
    public async Task<IActionResult> UpdateProfile([FromForm] UpdateProfileDto dto, IFormFile? profilePicture)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try { return Ok(await _auth.UpdateProfileAsync(userId, dto, profilePicture)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [Authorize]
    [HttpPut("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            await _auth.ChangePasswordAsync(userId, dto.CurrentPassword, dto.NewPassword);
            return Ok(new { message = "Password changed successfully." });
        }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
        catch (UnauthorizedAccessException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpGet("users/{userId:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetUserProfile(Guid userId)
    {
        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound(new { error = "User not found." });
        var capsuleCount = await _db.Capsules.CountAsync(c => c.SenderId == userId);
        var postCount = await _db.Posts.CountAsync(p => p.UserId == userId);
        return Ok(new UserProfileDto
        {
            Id = user.Id, DisplayName = user.DisplayName, Email = user.Email,
            ProfilePictureUrl = user.ProfilePictureUrl, Bio = user.Bio,
            AccentColor = user.AccentColor, CreatedAt = user.CreatedAt,
            CapsuleCount = capsuleCount, PostCount = postCount
        });
    }

    [HttpPost("google")]
    public async Task<IActionResult> GoogleLogin([FromBody] SocialAuthDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.AccessToken)) return BadRequest(new { error = "Access token required" });
        try { return Ok(await _auth.LoginWithGoogleAsync(dto.AccessToken, dto.IsIdToken)); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpPost("facebook")]
    public async Task<IActionResult> FacebookLogin([FromBody] SocialAuthDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.AccessToken)) return BadRequest(new { error = "Access token required" });
        try { return Ok(await _auth.LoginWithFacebookAsync(dto.AccessToken)); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid email format" });
        await _auth.ForgotPasswordAsync(dto.Email);
        return Ok(new { message = "If that email exists, a reset link has been sent." });
    }

    [HttpGet("validate-reset-token")]
    public async Task<IActionResult> ValidateResetToken([FromQuery] string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return BadRequest(new { error = "Token required" });
        return Ok(await _auth.ValidateResetTokenAsync(token));
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input" });
        var success = await _auth.ResetPasswordAsync(dto.Token, dto.NewPassword);
        if (!success) return BadRequest(new { error = "This reset link is invalid or has expired" });
        return Ok(new { message = "Password updated successfully" });
    }

    [Authorize]
    [HttpPut("fcm-token")]
    public async Task<IActionResult> UpdateFcmToken([FromBody] UpdateFcmTokenDto dto)
    {
        var userId = Guid.Parse(User.FindFirstValue(System.Security.Claims.ClaimTypes.NameIdentifier)!);
        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound(new { error = "User not found." });
        user.FcmToken = dto.Token;
        await _db.SaveChangesAsync();
        return Ok();
    }
}
