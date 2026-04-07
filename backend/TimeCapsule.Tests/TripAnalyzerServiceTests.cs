using Xunit;
using FluentAssertions;
using Moq;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Trip;
using TimeCapsule.API.Models;
using TimeCapsule.API.Services;

namespace TimeCapsule.Tests;

[Trait("Category", "Unit")]
public class TripAnalyzerServiceTests
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

    private static TripAnalyzerService CreateService(AppDbContext db)
    {
        var logger = new Mock<ILogger<TripAnalyzerService>>().Object;
        return new TripAnalyzerService(db, logger);
    }

    private static async Task<Guid> SeedUserAsync(AppDbContext db, string email = "trip@example.com")
    {
        var user = new User
        {
            Id           = Guid.NewGuid(),
            Email        = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            DisplayName  = "Trip User",
            CreatedAt    = DateTime.UtcNow
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user.Id;
    }

    // -----------------------------------------------------------------------
    // 1. Paris with sufficient budget → isBudgetSufficient:true, warning:null,
    //    days[0].recommendedSpots non-empty
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_ParisSufficientBudget_ReturnsValidItinerary()
    {
        using var db = CreateDb("trip_paris_ok_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        var dto = new TripRequestDto
        {
            Destination  = "Paris",
            NumberOfDays = 3,
            TotalBudget  = 1500m   // 500/day — well above 50
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        result.IsBudgetSufficient.Should().BeTrue();
        result.Warning.Should().BeNull();
        result.Days.Should().HaveCount(3);
        result.Days[0].RecommendedSpots.Should().NotBeEmpty(
            "Paris day 1 should have recommended spots seeded in the mock data");
    }

    // -----------------------------------------------------------------------
    // 2. Tokyo with 3 days → days.Count == 3
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_Tokyo3Days_Returns3DayPlan()
    {
        using var db = CreateDb("trip_tokyo_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        var dto = new TripRequestDto
        {
            Destination  = "Tokyo",
            NumberOfDays = 3,
            TotalBudget  = 900m
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        result.Days.Should().HaveCount(3, "exactly 3 day plans should be generated");
        result.Days.Should().OnlyContain(d => !string.IsNullOrWhiteSpace(d.Theme));
    }

    // -----------------------------------------------------------------------
    // 3. Budget < 30/day → isBudgetSufficient:false, warning contains "extremely tight"
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_BudgetUnder30PerDay_ReturnsTightWarning()
    {
        using var db = CreateDb("trip_budget_low_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        var dto = new TripRequestDto
        {
            Destination  = "London",
            NumberOfDays = 5,
            TotalBudget  = 100m   // 20/day → extremely tight
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        result.IsBudgetSufficient.Should().BeFalse();
        result.Warning.Should().NotBeNullOrWhiteSpace();
        result.Warning.Should().Contain("extremely tight",
            "warning text must mention 'extremely tight' when daily budget < 30");
    }

    // -----------------------------------------------------------------------
    // 4. Budget between 30 and 50/day → warning contains "tight"
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_BudgetBetween30And50PerDay_ReturnsTightBudgetWarning()
    {
        using var db = CreateDb("trip_budget_medium_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        var dto = new TripRequestDto
        {
            Destination  = "Bangkok",
            NumberOfDays = 4,
            TotalBudget  = 160m   // 40/day → between 30 and 50
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        result.IsBudgetSufficient.Should().BeFalse();
        result.Warning.Should().NotBeNullOrWhiteSpace();
        result.Warning.Should().Contain("tight",
            "warning must mention 'tight' when daily budget is between 30 and 50");
        result.Warning.Should().NotContain("extremely tight",
            "this warning level should not say 'extremely tight'");
    }

    // -----------------------------------------------------------------------
    // 5. Unknown destination → returns generic itinerary with correct day count
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_UnknownDestination_ReturnsGenericItinerary()
    {
        using var db = CreateDb("trip_generic_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        const int requestedDays = 5;
        var dto = new TripRequestDto
        {
            Destination  = "Atlantis",   // not in the known-destination list
            NumberOfDays = requestedDays,
            TotalBudget  = 2000m
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        result.Days.Should().HaveCount(requestedDays,
            "generic itinerary must produce exactly the requested number of days");
        result.Destination.Should().Be("Atlantis");
        // Generic themes contain the destination name
        result.Days.Should().OnlyContain(d => !string.IsNullOrWhiteSpace(d.Theme));
    }

    // -----------------------------------------------------------------------
    // 6. GetHistoryAsync returns only the requesting user's analyses
    // -----------------------------------------------------------------------
    [Fact]
    public async Task GetHistoryAsync_ReturnsOnlyRequestingUsersAnalyses()
    {
        using var db  = CreateDb("trip_history_" + Guid.NewGuid());
        var svc       = CreateService(db);
        var userId1   = await SeedUserAsync(db, "user1@trip.com");
        var userId2   = await SeedUserAsync(db, "user2@trip.com");

        // Two analyses for user1, one for user2
        await svc.AnalyzeAsync(userId1, new TripRequestDto { Destination = "Paris",  NumberOfDays = 2, TotalBudget = 800m });
        await svc.AnalyzeAsync(userId1, new TripRequestDto { Destination = "Tokyo",  NumberOfDays = 3, TotalBudget = 900m });
        await svc.AnalyzeAsync(userId2, new TripRequestDto { Destination = "London", NumberOfDays = 4, TotalBudget = 1200m });

        var history = await svc.GetHistoryAsync(userId1);

        history.Should().HaveCount(2, "only user1's analyses should be returned");
        history.Should().OnlyContain(t =>
            t.Destination == "Paris" || t.Destination == "Tokyo");
    }

    // -----------------------------------------------------------------------
    // 7. AnalyzeAsync persists the analysis to the database
    // -----------------------------------------------------------------------
    [Fact]
    public async Task AnalyzeAsync_PersistsTripAnalysisToDatabase()
    {
        using var db = CreateDb("trip_persist_" + Guid.NewGuid());
        var svc    = CreateService(db);
        var userId = await SeedUserAsync(db);

        var dto = new TripRequestDto
        {
            Destination  = "New York",
            NumberOfDays = 3,
            TotalBudget  = 1500m
        };

        var result = await svc.AnalyzeAsync(userId, dto);

        // Reload from DB
        var stored = await db.TripAnalyses.FindAsync(result.Id);

        stored.Should().NotBeNull("the analysis must be persisted to the database");
        stored!.UserId.Should().Be(userId);
        stored.Destination.Should().Be("New York");
        stored.NumberOfDays.Should().Be(3);
        stored.TotalBudget.Should().Be(1500m);
        stored.AIResponseJson.Should().NotBeNullOrWhiteSpace(
            "the serialised JSON response must be stored");
    }
}
