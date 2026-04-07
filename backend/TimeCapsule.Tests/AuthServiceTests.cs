using Xunit;
using FluentAssertions;
using Moq;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Auth;
using TimeCapsule.API.Models;
using TimeCapsule.API.Services;

namespace TimeCapsule.Tests;

[Trait("Category", "Unit")]
public class AuthServiceTests
{
    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static AppDbContext CreateDb(string dbName)
    {
        var opts = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(dbName)
            .Options;
        return new AppDbContext(opts);
    }

    private static IConfiguration BuildConfig()
    {
        var dict = new Dictionary<string, string?>
        {
            ["JwtSettings:Secret"]        = "TimeCapsule_SuperSecretKey_MustBe32CharsLong!",
            ["JwtSettings:ExpiresInDays"] = "30",
            ["JwtSettings:Issuer"]        = "TimeCapsuleAPI",
            ["JwtSettings:Audience"]      = "TimeCapsuleClient"
        };
        return new ConfigurationBuilder().AddInMemoryCollection(dict).Build();
    }

    private static AuthService CreateService(AppDbContext db)
    {
        var config  = BuildConfig();
        var logger  = new Mock<ILogger<AuthService>>().Object;
        var fileUpload = new Mock<IFileUploadService>().Object;
        var emailService = new Mock<IEmailService>().Object;
        var httpClientFactory = new Mock<IHttpClientFactory>().Object;
        return new AuthService(db, config, logger, fileUpload, emailService, httpClientFactory);
    }

    // -----------------------------------------------------------------------
    // 1. Register with valid data → returns AuthResponseDto with token and user
    // -----------------------------------------------------------------------
    [Fact]
    public async Task RegisterAsync_ValidData_ReturnsAuthResponseWithToken()
    {
        using var db = CreateDb("auth_register_valid_" + Guid.NewGuid());
        var svc = CreateService(db);

        var dto = new RegisterDto
        {
            Email       = "alice@example.com",
            Password    = "password123",
            DisplayName = "Alice"
        };

        var result = await svc.RegisterAsync(dto);

        result.Should().NotBeNull();
        result.Token.Should().NotBeNullOrWhiteSpace("a JWT token must be returned");
        result.User.Should().NotBeNull();
        result.User.Email.Should().Be("alice@example.com");
        result.User.DisplayName.Should().Be("Alice");
        result.User.Id.Should().NotBeEmpty();
    }

    // -----------------------------------------------------------------------
    // 2. Register with duplicate email → throws InvalidOperationException
    // -----------------------------------------------------------------------
    [Fact]
    public async Task RegisterAsync_DuplicateEmail_ThrowsInvalidOperationException()
    {
        using var db = CreateDb("auth_register_dup_" + Guid.NewGuid());
        var svc = CreateService(db);

        var dto = new RegisterDto
        {
            Email       = "bob@example.com",
            Password    = "password123",
            DisplayName = "Bob"
        };

        await svc.RegisterAsync(dto); // first registration succeeds

        Func<Task> act = () => svc.RegisterAsync(dto);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*already in use*");
    }

    // -----------------------------------------------------------------------
    // 3. Login with correct credentials → returns AuthResponseDto
    // -----------------------------------------------------------------------
    [Fact]
    public async Task LoginAsync_CorrectCredentials_ReturnsAuthResponse()
    {
        using var db = CreateDb("auth_login_ok_" + Guid.NewGuid());
        var svc = CreateService(db);

        var register = new RegisterDto
        {
            Email       = "carol@example.com",
            Password    = "securePass!",
            DisplayName = "Carol"
        };
        await svc.RegisterAsync(register);

        var login = new LoginDto { Email = "carol@example.com", Password = "securePass!" };
        var result = await svc.LoginAsync(login);

        result.Should().NotBeNull();
        result.Token.Should().NotBeNullOrWhiteSpace();
        result.User.Email.Should().Be("carol@example.com");
    }

    // -----------------------------------------------------------------------
    // 4. Login with wrong password → throws UnauthorizedAccessException
    // -----------------------------------------------------------------------
    [Fact]
    public async Task LoginAsync_WrongPassword_ThrowsUnauthorizedAccessException()
    {
        using var db = CreateDb("auth_login_bad_pass_" + Guid.NewGuid());
        var svc = CreateService(db);

        var register = new RegisterDto
        {
            Email       = "dave@example.com",
            Password    = "correctPass",
            DisplayName = "Dave"
        };
        await svc.RegisterAsync(register);

        Func<Task> act = () => svc.LoginAsync(new LoginDto
        {
            Email    = "dave@example.com",
            Password = "wrongPass"
        });

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("*Invalid email or password*");
    }

    // -----------------------------------------------------------------------
    // 5. Login with non-existent email → throws UnauthorizedAccessException
    // -----------------------------------------------------------------------
    [Fact]
    public async Task LoginAsync_NonExistentEmail_ThrowsUnauthorizedAccessException()
    {
        using var db = CreateDb("auth_login_no_user_" + Guid.NewGuid());
        var svc = CreateService(db);

        Func<Task> act = () => svc.LoginAsync(new LoginDto
        {
            Email    = "nobody@example.com",
            Password = "anyPassword"
        });

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("*Invalid email or password*");
    }

    // -----------------------------------------------------------------------
    // 6. GetCurrentUserAsync with valid userId → returns UserDto
    // -----------------------------------------------------------------------
    [Fact]
    public async Task GetCurrentUserAsync_ValidUserId_ReturnsUserDto()
    {
        using var db = CreateDb("auth_getme_" + Guid.NewGuid());
        var svc = CreateService(db);

        var register = new RegisterDto
        {
            Email       = "eve@example.com",
            Password    = "password123",
            DisplayName = "Eve"
        };
        var registered = await svc.RegisterAsync(register);
        var userId = registered.User.Id;

        var userDto = await svc.GetCurrentUserAsync(userId);

        userDto.Should().NotBeNull();
        userDto.Id.Should().Be(userId);
        userDto.Email.Should().Be("eve@example.com");
        userDto.DisplayName.Should().Be("Eve");
    }
}
