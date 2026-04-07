using Xunit;
using FluentAssertions;
using TimeCapsule.API.Services;

namespace TimeCapsule.Tests;

[Trait("Category", "Unit")]
public class GpsHelperTests
{
    // -----------------------------------------------------------------------
    // Fact: same coordinates → 0 meters
    // -----------------------------------------------------------------------
    [Fact]
    public void CalculateDistanceInMeters_SameCoordinates_ReturnsZero()
    {
        var distance = GpsHelper.CalculateDistanceInMeters(40.7128, -74.006, 40.7128, -74.006);

        distance.Should().Be(0.0);
    }

    // -----------------------------------------------------------------------
    // Theory: known distances
    // -----------------------------------------------------------------------
    [Theory]
    [InlineData(0.0, 0.0, 0.0, 1.0, 111195.0, 100.0)]   // 1° longitude at equator ≈ 111195 m
    [InlineData(40.7128, -74.006, 51.5074, -0.1278, 5570000.0, 50000.0)] // NY → London ≈ 5570 km
    public void CalculateDistanceInMeters_KnownPoints_IsWithinTolerance(
        double lat1, double lon1, double lat2, double lon2,
        double expectedMeters, double toleranceMeters)
    {
        var distance = GpsHelper.CalculateDistanceInMeters(lat1, lon1, lat2, lon2);

        distance.Should().BeApproximately(expectedMeters, toleranceMeters,
            $"distance from ({lat1},{lon1}) to ({lat2},{lon2}) should be ≈{expectedMeters}m ±{toleranceMeters}m");
    }

    // -----------------------------------------------------------------------
    // Fact: very close points (≈1 m apart) → result is well under 5 m
    // Δlat of 0.000009° ≈ 1 m
    // -----------------------------------------------------------------------
    [Fact]
    public void CalculateDistanceInMeters_VeryClosePoints_LessThanFiveMeters()
    {
        var distance = GpsHelper.CalculateDistanceInMeters(48.8566, 2.3522, 48.8566 + 0.000009, 2.3522);

        distance.Should().BeLessThan(5.0);
    }

    // -----------------------------------------------------------------------
    // Fact: symmetry — dist(A,B) == dist(B,A)
    // -----------------------------------------------------------------------
    [Fact]
    public void CalculateDistanceInMeters_IsSymmetric()
    {
        double lat1 = 35.6895, lon1 = 139.6917; // Tokyo
        double lat2 = -33.8688, lon2 = 151.2093; // Sydney

        var ab = GpsHelper.CalculateDistanceInMeters(lat1, lon1, lat2, lon2);
        var ba = GpsHelper.CalculateDistanceInMeters(lat2, lon2, lat1, lon1);

        ab.Should().BeApproximately(ba, 0.001,
            "distance calculation must be symmetric");
    }

    // -----------------------------------------------------------------------
    // Fact: north / south poles are equidistant from the equator (0°)
    // North Pole (90,0) and South Pole (-90,0) should both be ≈10001966 m from (0,0)
    // -----------------------------------------------------------------------
    [Fact]
    public void CalculateDistanceInMeters_PolesEquidistantFromEquator()
    {
        var distNorth = GpsHelper.CalculateDistanceInMeters(0.0, 0.0, 90.0, 0.0);
        var distSouth = GpsHelper.CalculateDistanceInMeters(0.0, 0.0, -90.0, 0.0);

        distNorth.Should().BeApproximately(distSouth, 1.0,
            "the north and south poles should be equidistant from the equator");
    }
}
