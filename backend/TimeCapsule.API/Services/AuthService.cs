using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Auth;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class AuthService : IAuthService
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;
    private readonly ILogger<AuthService> _logger;
    private readonly IFileUploadService _fileUpload;
    private readonly IEmailService _emailService;
    private readonly IHttpClientFactory _httpClientFactory;

    public AuthService(AppDbContext db, IConfiguration config, ILogger<AuthService> logger,
        IFileUploadService fileUpload, IEmailService emailService, IHttpClientFactory httpClientFactory)
    {
        _db = db;
        _config = config;
        _logger = logger;
        _fileUpload = fileUpload;
        _emailService = emailService;
        _httpClientFactory = httpClientFactory;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        var email = dto.Email.Trim().ToLower();
        if (await _db.Users.AnyAsync(u => u.Email == email))
        {
            _logger.LogInformation("Registration failed: email {Email} already exists", email);
            throw new InvalidOperationException("Email already in use.");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
            DisplayName = dto.DisplayName.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();
        _logger.LogInformation("User registered: {Email}", email);
        return new AuthResponseDto { Token = GenerateToken(user), User = ToUserDto(user) };
    }

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var email = dto.Email.Trim().ToLower();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user == null || user.PasswordHash == null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
        {
            _logger.LogInformation("Login failed for {Email}", email);
            throw new UnauthorizedAccessException("Invalid email or password.");
        }

        _logger.LogInformation("Login success for {Email}", email);
        return new AuthResponseDto { Token = GenerateToken(user), User = ToUserDto(user) };
    }

    public async Task<UserDto> GetCurrentUserAsync(Guid userId)
    {
        var user = await _db.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");
        return ToUserDto(user);
    }

    public async Task<UserDto> UpdateProfileAsync(Guid userId, UpdateProfileDto dto, IFormFile? profilePicture)
    {
        var user = await _db.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");

        if (!string.IsNullOrWhiteSpace(dto.DisplayName))
            user.DisplayName = dto.DisplayName.Trim();

        if (dto.Bio != null)
            user.Bio = dto.Bio.Trim();

        if (!string.IsNullOrWhiteSpace(dto.AccentColor))
            user.AccentColor = dto.AccentColor.Trim();

        if (profilePicture != null)
            user.ProfilePictureUrl = await _fileUpload.SaveFileAsync(profilePicture);

        await _db.SaveChangesAsync();
        return ToUserDto(user);
    }

    public async Task<AuthResponseDto> LoginWithGoogleAsync(string googleToken, bool isIdToken = false)
    {
        _logger.LogInformation("Google login attempt (isIdToken={IsIdToken})", isIdToken);
        using var client = _httpClientFactory.CreateClient();

        // Try idToken first (more secure), then fall back to accessToken endpoint
        string googleId, email, name;
        if (isIdToken)
        {
            var resp = await client.GetAsync($"https://oauth2.googleapis.com/tokeninfo?id_token={googleToken}");
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException("Invalid Google ID token");
            var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
            googleId = json.GetProperty("sub").GetString()!;
            email = json.GetProperty("email").GetString()!.ToLower();
            name = json.TryGetProperty("name", out var n) ? (n.GetString() ?? email) : email;
        }
        else
        {
            var resp = await client.GetAsync($"https://oauth2.googleapis.com/tokeninfo?access_token={googleToken}");
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException("Invalid Google access token");
            var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
            googleId = json.GetProperty("sub").GetString()!;
            email = json.GetProperty("email").GetString()!.ToLower();
            name = json.TryGetProperty("name", out var n) ? (n.GetString() ?? email) : email;
        }

        var user = await _db.Users.FirstOrDefaultAsync(u => u.GoogleId == googleId)
                 ?? await _db.Users.FirstOrDefaultAsync(u => u.Email == email);

        if (user == null)
        {
            user = new User { Id = Guid.NewGuid(), Email = email, DisplayName = name, GoogleId = googleId, AuthProvider = "Google", CreatedAt = DateTime.UtcNow };
            _db.Users.Add(user);
        }
        else
        {
            user.GoogleId = googleId;
        }
        await _db.SaveChangesAsync();
        _logger.LogInformation("Google login success for email: {Email}", email);
        return new AuthResponseDto { Token = GenerateToken(user), User = ToUserDto(user) };
    }

    public async Task<AuthResponseDto> LoginWithFacebookAsync(string facebookAccessToken)
    {
        _logger.LogInformation("Facebook login attempt");
        using var client = _httpClientFactory.CreateClient();
        var appId = _config["OAuth:Facebook:AppId"];
        var appSecret = _config["OAuth:Facebook:AppSecret"];

        var verifyResp = await client.GetAsync($"https://graph.facebook.com/debug_token?input_token={facebookAccessToken}&access_token={appId}|{appSecret}");
        if (!verifyResp.IsSuccessStatusCode)
            throw new InvalidOperationException("Invalid social login token");

        var dataResp = await client.GetAsync($"https://graph.facebook.com/me?access_token={facebookAccessToken}&fields=id,name,email");
        if (!dataResp.IsSuccessStatusCode)
            throw new InvalidOperationException("Invalid social login token");

        var json = await dataResp.Content.ReadFromJsonAsync<JsonElement>();
        var facebookId = json.GetProperty("id").GetString()!;
        var email = json.TryGetProperty("email", out var e) ? (e.GetString() ?? $"{facebookId}@facebook.com").ToLower() : $"{facebookId}@facebook.com";
        var name = json.TryGetProperty("name", out var nm) ? (nm.GetString() ?? email) : email;

        var user = await _db.Users.FirstOrDefaultAsync(u => u.FacebookId == facebookId)
                 ?? await _db.Users.FirstOrDefaultAsync(u => u.Email == email);

        if (user == null)
        {
            user = new User { Id = Guid.NewGuid(), Email = email, DisplayName = name, FacebookId = facebookId, AuthProvider = "Facebook", CreatedAt = DateTime.UtcNow };
            _db.Users.Add(user);
        }
        else
        {
            user.FacebookId = facebookId;
        }
        await _db.SaveChangesAsync();
        _logger.LogInformation("Facebook login attempt for user ID: {FacebookId}", facebookId);
        return new AuthResponseDto { Token = GenerateToken(user), User = ToUserDto(user) };
    }

    public async Task ForgotPasswordAsync(string email)
    {
        _logger.LogInformation("Password reset requested for email: {Email}", email);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email.ToLower());
        if (user == null) return; // silent — never reveal whether email exists

        // invalidate existing unexpired tokens
        var oldTokens = await _db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && t.UsedAt == null && t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync();
        foreach (var t in oldTokens) t.UsedAt = DateTime.UtcNow;

        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        _db.PasswordResetTokens.Add(new PasswordResetToken
        {
            Id = Guid.NewGuid(), UserId = user.Id, Token = token,
            ExpiresAt = DateTime.UtcNow.AddHours(1), CreatedAt = DateTime.UtcNow
        });
        await _db.SaveChangesAsync();

        var resetUrl = $"{_config["App:FrontendResetUrl"]}?token={token}";
        await _emailService.SendPasswordResetEmailAsync(email, resetUrl);
    }

    public async Task<ValidateResetTokenResponseDto> ValidateResetTokenAsync(string token)
    {
        var entry = await _db.PasswordResetTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.Token == token && t.UsedAt == null && t.ExpiresAt > DateTime.UtcNow);
        if (entry == null) return new ValidateResetTokenResponseDto { IsValid = false };
        return new ValidateResetTokenResponseDto { IsValid = true, Email = entry.User.Email };
    }

    public async Task<bool> ResetPasswordAsync(string token, string newPassword)
    {
        var entry = await _db.PasswordResetTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.Token == token && t.UsedAt == null && t.ExpiresAt > DateTime.UtcNow);
        if (entry == null) return false;

        entry.User.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        entry.User.AuthProvider = "Email";
        entry.UsedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        _logger.LogInformation("Password reset completed for user ID: {UserId}", entry.UserId);
        return true;
    }

    private string GenerateToken(User user)
    {
        var secret = _config["JwtSettings:Secret"]!;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddDays(int.Parse(_config["JwtSettings:ExpiresInDays"] ?? "30"));

        var token = new JwtSecurityToken(
            issuer: _config["JwtSettings:Issuer"],
            audience: _config["JwtSettings:Audience"],
            claims: new[] { new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()) },
            expires: expires,
            signingCredentials: creds
        );
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static UserDto ToUserDto(User u) => new()
    {
        Id = u.Id, Email = u.Email, DisplayName = u.DisplayName,
        ProfilePictureUrl = u.ProfilePictureUrl, CreatedAt = u.CreatedAt
    };
}
