namespace TimeCapsule.API.DTOs.Spin;

public class SpinResponseDto
{
    public string PrizeName { get; set; } = string.Empty;
    public int PointsWon { get; set; }
    public int NewBalance { get; set; }
    public int SegmentIndex { get; set; }  // 0-7, tells the wheel which segment to land on
}
