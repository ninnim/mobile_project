using Xunit;
using FluentAssertions;
using Moq;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Capsule;
using TimeCapsule.API.Models;
using TimeCapsule.API.Services;

namespace TimeCapsule.Tests;

[Trait("Category", "Unit")]
public class CapsuleServiceTests
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

    private static CapsuleService CreateService(AppDbContext db, IFileUploadService? fileUpload = null)
    {
        fileUpload ??= new Mock<IFileUploadService>().Object;
        var logger = new Mock<ILogger<CapsuleService>>().Object;
        return new CapsuleService(db, fileUpload, logger);
    }

    /// <summary>Seed a User row and return its Id.</summary>
    private static async Task<Guid> SeedUserAsync(AppDbContext db, string email = "test@example.com")
    {
        var user = new User
        {
            Id           = Guid.NewGuid(),
            Email        = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            DisplayName  = "Test User",
            CreatedAt    = DateTime.UtcNow
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user.Id;
    }

    /// <summary>Seed a Capsule row and return its Id.</summary>
    private static async Task<Guid> SeedCapsuleAsync(
        AppDbContext db,
        Guid senderId,
        bool isPublic       = false,
        string status       = "Locked",
        DateTime? unlockDate = null,
        double latitude      = 40.7128,
        double longitude     = -74.006,
        int proximityTolerance = 50)
    {
        var capsule = new Capsule
        {
            Id                 = Guid.NewGuid(),
            SenderId           = senderId,
            Title              = "Test Capsule",
            Message            = "Test Message",
            Latitude           = (decimal)latitude,
            Longitude          = (decimal)longitude,
            UnlockDate         = unlockDate?.ToUniversalTime() ?? DateTime.UtcNow.AddDays(-1),
            IsPublic           = isPublic,
            Status             = status,
            ProximityTolerance = proximityTolerance,
            PointsReward       = 10,
            Media              = new List<CapsuleMedia>(),
            CreatedAt          = DateTime.UtcNow
        };
        db.Capsules.Add(capsule);
        await db.SaveChangesAsync();
        return capsule.Id;
    }

    // -----------------------------------------------------------------------
    // 1. GetUserCapsulesAsync returns only the requesting user's capsules
    // -----------------------------------------------------------------------
    [Fact]
    public async Task GetMyCapsulesAsync_ReturnsOnlyOwnersCapsules()
    {
        using var db = CreateDb("caps_get_mine_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId1 = await SeedUserAsync(db, "user1@test.com");
        var userId2 = await SeedUserAsync(db, "user2@test.com");

        await SeedCapsuleAsync(db, userId1);
        await SeedCapsuleAsync(db, userId1);
        await SeedCapsuleAsync(db, userId2); // belongs to a different user

        var result = await svc.GetMyCapsulesAsync(userId1);

        result.Should().HaveCount(2, "only user1's capsules should be returned");
        result.Should().OnlyContain(c => c.SenderId == userId1);
    }

    // -----------------------------------------------------------------------
    // 2. GetPublicCapsulesAsync returns only public capsules;
    //    message is null for locked ones
    // -----------------------------------------------------------------------
    [Fact]
    public async Task GetPublicCapsulesAsync_ReturnsOnlyPublicCapsules_AndHidesLockedMessages()
    {
        using var db = CreateDb("caps_public_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId = await SeedUserAsync(db);

        // Public + Locked  → message hidden
        var publicLockedId   = await SeedCapsuleAsync(db, userId, isPublic: true,  status: "Locked");
        // Public + Unlocked → message visible
        var publicUnlockedId = await SeedCapsuleAsync(db, userId, isPublic: true,  status: "Unlocked");
        // Private           → must NOT appear
        await SeedCapsuleAsync(db, userId, isPublic: false, status: "Locked");

        var result = await svc.GetPublicCapsulesAsync();

        result.Should().HaveCount(2, "only public capsules should be returned");
        result.Should().NotContain(c => c.IsPublic == false);

        var lockedCapsule = result.First(c => c.Id == publicLockedId);
        lockedCapsule.Message.Should().BeNull("locked capsule message must be hidden");

        var unlockedCapsule = result.First(c => c.Id == publicUnlockedId);
        unlockedCapsule.Message.Should().Be("Test Message");
    }

    // -----------------------------------------------------------------------
    // 3. UnlockAsync — capsule unlock date is in the future → success:false
    // -----------------------------------------------------------------------
    [Fact]
    public async Task UnlockAsync_TooEarly_ReturnsFalse()
    {
        using var db = CreateDb("caps_unlock_tooearly_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId    = await SeedUserAsync(db);
        var capsuleId = await SeedCapsuleAsync(
            db, userId,
            unlockDate: DateTime.UtcNow.AddDays(5),    // future
            latitude: 40.7128, longitude: -74.006);

        var unlockDto = new UnlockCapsuleDto { Latitude = 40.7128, Longitude = -74.006 };
        var result = await svc.UnlockAsync(capsuleId, userId, unlockDto);

        result.Success.Should().BeFalse("unlock date has not been reached yet");
        result.Message.Should().Contain("cannot be unlocked until");
    }

    // -----------------------------------------------------------------------
    // 4. UnlockAsync — user is too far away → success:false with DistanceMeters
    // -----------------------------------------------------------------------
    [Fact]
    public async Task UnlockAsync_TooFarAway_ReturnsFalseWithDistance()
    {
        using var db = CreateDb("caps_unlock_toofar_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId = await SeedUserAsync(db);
        // Capsule at NYC
        var capsuleId = await SeedCapsuleAsync(
            db, userId,
            unlockDate: DateTime.UtcNow.AddDays(-1),  // past → time OK
            latitude: 40.7128, longitude: -74.006,
            proximityTolerance: 50);

        // User is at London — ~5570 km away
        var unlockDto = new UnlockCapsuleDto { Latitude = 51.5074, Longitude = -0.1278 };
        var result = await svc.UnlockAsync(capsuleId, userId, unlockDto);

        result.Success.Should().BeFalse("user is far outside the proximity tolerance");
        result.DistanceMeters.Should().BeGreaterThan(50,
            "reported distance must exceed the 50 m tolerance");
        result.Message.Should().Contain("meters away");
    }

    // -----------------------------------------------------------------------
    // 5. UnlockAsync — within range and after unlock date → success:true,
    //    capsule status becomes "Unlocked"
    // -----------------------------------------------------------------------
    [Fact]
    public async Task UnlockAsync_WithinRangeAndAfterDate_SucceedsAndUpdatesStatus()
    {
        using var db = CreateDb("caps_unlock_ok_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId = await SeedUserAsync(db);
        var capsuleId = await SeedCapsuleAsync(
            db, userId,
            unlockDate: DateTime.UtcNow.AddDays(-1),  // past
            latitude: 40.7128, longitude: -74.006,
            proximityTolerance: 50);

        // User is at the same location → distance ≈ 0
        var unlockDto = new UnlockCapsuleDto { Latitude = 40.7128, Longitude = -74.006 };
        var result = await svc.UnlockAsync(capsuleId, userId, unlockDto);

        result.Success.Should().BeTrue("user is within range and date has passed");
        result.Capsule.Should().NotBeNull();
        result.Capsule!.Status.Should().Be("Unlocked");
        result.PointsAwarded.Should().Be(10);

        // Verify persistence in DB
        var dbCapsule = await db.Capsules.FindAsync(capsuleId);
        dbCapsule!.Status.Should().Be("Unlocked");
    }

    // -----------------------------------------------------------------------
    // 6. CreateAsync with invalid proximity tolerance → throws ArgumentException
    // -----------------------------------------------------------------------
    [Fact]
    public async Task CreateAsync_InvalidProximityTolerance_ThrowsArgumentException()
    {
        using var db = CreateDb("caps_create_bad_tol_" + Guid.NewGuid());
        var svc = CreateService(db);

        var userId = await SeedUserAsync(db);

        var dto = new CreateCapsuleDto
        {
            Title              = "Bad Tolerance Capsule",
            Message            = "A message",
            Latitude           = 40.7128,
            Longitude          = -74.006,
            UnlockDate         = DateTime.UtcNow.AddDays(1),
            ProximityTolerance = 30,   // invalid — only 5 or 50 are valid
            MediaFiles         = null
        };

        Func<Task> act = () => svc.CreateAsync(userId, dto);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*ProximityTolerance must be 5 or 50*");
    }
}
