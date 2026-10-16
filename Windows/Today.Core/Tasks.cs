using System.Globalization;
using System.Text;
using System.Text.Json.Serialization;

namespace Today.Core;

public sealed record TodoItem
{
    public required Guid Id { get; init; }
    public required string Title { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
    public required DateTimeOffset ScheduledFor { get; init; }
    public Guid? CategoryID { get; init; }
    public DateTimeOffset? DueDate { get; init; }
    public DateTimeOffset? CompletedAt { get; init; }
    public required DateTimeOffset UpdatedAt { get; init; }
    public string Priority { get; init; } = "none";
    [JsonIgnore] public bool IsCompleted => CompletedAt.HasValue;
    [JsonIgnore] public int FlameCount => TaskRules.Flames(Priority);
}

public sealed record TaskCategory(Guid Id, string Name, string SystemImage = "folder")
{
    public static readonly Guid WorkID = Guid.Parse("A91B6B75-5BF2-45F4-B00D-1C24F6DBF001");
    public static readonly Guid PersonalID = Guid.Parse("A91B6B75-5BF2-45F4-B00D-1C24F6DBF002");
    public static TaskCategory[] Defaults =>
    [new(WorkID, "Работа", "briefcase"), new(PersonalID, "Личное", "person")];
    [JsonIgnore] public bool IsSystem => Id == WorkID || Id == PersonalID;
    [JsonIgnore] public string DisplayName => Id == WorkID ? I18n.Text("Работа", "Work") :
        Id == PersonalID ? I18n.Text("Личное", "Personal") : Name;
}

public static class TaskRules
{
    public static readonly string[] Priorities = ["none", "low", "medium", "high"];
    public static string[] PriorityNames => [I18n.Text("Без приоритета", "No priority"), I18n.Text("Низкий · 1 огонёк", "Low · 1 flame"), I18n.Text("Средний · 2 огонька", "Medium · 2 flames"), I18n.Text("Высокий · 3 огонька", "High · 3 flames")];
    public static int Flames(string? priority) => priority switch { "high" => 3, "medium" => 2, "low" => 1, _ => 0 };

    public static string Normalize(string value) => new(value.ToLowerInvariant().Normalize(NormalizationForm.FormD)
        .Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark).ToArray());

    public static bool Matches(TodoItem task, string query, Guid? category) =>
        (!category.HasValue || task.CategoryID == category) &&
        Normalize(query).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)
            .All(word => Normalize(task.Title).Contains(word, StringComparison.Ordinal));

    public static DateOnly LocalDay(DateTimeOffset date, TimeZoneInfo zone) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(date, zone).DateTime);

    public static IEnumerable<TodoItem> Pending(IEnumerable<TodoItem> tasks) => tasks.Where(t => !t.IsCompleted)
        .OrderByDescending(t => t.FlameCount).ThenBy(t => t.CreatedAt);

    public static IEnumerable<TodoItem> History(IEnumerable<TodoItem> tasks, TimeZoneInfo zone) =>
        tasks.Where(t => t.IsCompleted).OrderByDescending(t => LocalDay(t.CompletedAt!.Value, zone))
            .ThenByDescending(t => t.FlameCount).ThenByDescending(t => t.CompletedAt);

    public static IEnumerable<TodoItem> CompletedToday(IEnumerable<TodoItem> tasks, DateTimeOffset now, TimeZoneInfo zone) =>
        History(tasks, zone).Where(t => LocalDay(t.CompletedAt!.Value, zone) == LocalDay(now, zone));

    public static DateTimeOffset LocalDeadline(DateTime date, string time, TimeZoneInfo zone)
    {
        if (!TimeOnly.TryParseExact(time.Trim(), ["H:mm", "HH:mm"], CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var clock))
            throw new ArgumentException(I18n.Text("Введите время от 00:00 до 23:59.", "Enter a time from 00:00 to 23:59."));
        var local = DateTime.SpecifyKind(date.Date.Add(clock.ToTimeSpan()), DateTimeKind.Unspecified);
        if (zone.IsInvalidTime(local)) throw new ArgumentException(I18n.Text("Такого времени нет из-за перевода часов. Выберите другое.", "This time does not exist due to daylight saving time. Choose another time."));
        return new DateTimeOffset(local, zone.GetUtcOffset(local));
    }
}
