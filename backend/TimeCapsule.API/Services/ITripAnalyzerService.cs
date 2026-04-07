using TimeCapsule.API.DTOs.Trip;

namespace TimeCapsule.API.Services;

public interface ITripAnalyzerService
{
    Task<TripResponseDto> AnalyzeAsync(Guid userId, TripRequestDto dto);
    Task<List<TripResponseDto>> GetHistoryAsync(Guid userId);
}
