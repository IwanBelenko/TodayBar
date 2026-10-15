using System.Text.Json;
using Today.Core;

var stamp = new DateTimeOffset(2026, 10, 15, 12, 0, 0, TimeSpan.Zero);
var tests = new (string Name, Action Test)[]
{
    ("Reads Mac JSON without priority", () => {
        var task = JsonSerializer.Deserialize<TodoItem>("""
            {"id":"A91B6B75-5BF2-45F4-B00D-1C24F6DBF003","title":"Отчёт\nкоманде","createdAt":"2026-10-15T09:00:00Z",
             "scheduledFor":"2026-10-15T09:00:00Z","updatedAt":"2026-10-15T09:00:00Z","categoryID":"A91B6B75-5BF2-45F4-B00D-1C24F6DBF001"}
            """, TaskStore.JsonOptions)!;
        Check(task.FlameCount == 0 && task.CategoryID == TaskCategory.WorkID && task.Title == "Отчёт\nкоманде");
    }),
    ("Unknown priorities remain readable", () => Check(TaskRules.Flames("urgent") == 0 && TaskRules.Flames(null) == 0)),
    ("All priority levels round trip", () => {
        foreach (var priority in TaskRules.Priorities) {
            var task = Item("Task", priority);
            Check(JsonSerializer.Deserialize<TodoItem>(JsonSerializer.Serialize(task, TaskStore.JsonOptions), TaskStore.JsonOptions) == task);
        }
    }),
    ("Writes Swift-compatible dates without fractional seconds", () => {
        var json = JsonSerializer.Serialize(Item("Task") with { DueDate = stamp.AddMilliseconds(123) }, TaskStore.JsonOptions);
        Check(json.Contains("2026-10-15T12:00:00Z") && !json.Contains(".123") && json.Contains("categoryID") == false);
    }),
    ("Search handles case, yo, newlines and multiple words", () => Check(TaskRules.Matches(Item("Отчёт\nКОМАНДЕ"), "  командЕ  отчет\n", null))),
    ("Search requires every word", () => Check(!TaskRules.Matches(Item("Отчёт команде"), "отчет завтра", null))),
    ("Search respects category", () => {
        var task = Item("Отчёт") with { CategoryID = TaskCategory.WorkID };
        Check(TaskRules.Matches(task, "", TaskCategory.WorkID)); Check(!TaskRules.Matches(task, "отчет", TaskCategory.PersonalID));
    }),
    ("Pending sorts 3,2,1,0 then oldest first", () => {
        var tasks = new[] { Item("none"), Item("high-new", "high") with { CreatedAt = stamp.AddHours(1) }, Item("low", "low"), Item("medium", "medium"), Item("high-old", "high") };
        Equal(TaskRules.Pending(tasks).Select(t => t.Title), ["high-old", "high-new", "medium", "low", "none"]);
    }),
    ("History keeps days before priority", () => {
        var tasks = new[] { Item("old-high", "high") with { CompletedAt = stamp.AddDays(-1) }, Item("today-none") with { CompletedAt = stamp }, Item("today-high", "high") with { CompletedAt = stamp.AddHours(-1) } };
        Equal(TaskRules.History(tasks, TimeZoneInfo.Utc).Select(t => t.Title), ["today-high", "today-none", "old-high"]);
    }),
    ("History uses local day, not UTC day", () => {
        var zone = TimeZoneInfo.CreateCustomTimeZone("Moscow-test", TimeSpan.FromHours(3), "Moscow-test", "Moscow-test");
        Check(TaskRules.LocalDay(stamp.AddHours(10), zone) == new DateOnly(2026, 10, 16));
    }),
    ("Today excludes past completions", () => Check(TaskRules.CompletedToday([Item("old") with { CompletedAt = stamp.AddDays(-1) }], stamp, TimeZoneInfo.Utc).Count() == 0)),
    ("Manual time accepts H:mm and HH:mm", () => {
        Check(TaskRules.LocalDeadline(stamp.Date, "9:07", TimeZoneInfo.Utc).Hour == 9);
        Check(TaskRules.LocalDeadline(stamp.Date, "23:59", TimeZoneInfo.Utc).Minute == 59);
    }),
    ("Manual time rejects invalid values", () => {
        foreach (var time in new[] { "24:00", "12:60", "9", "abc", "" }) Throws<ArgumentException>(() => TaskRules.LocalDeadline(stamp.Date, time, TimeZoneInfo.Utc));
    }),
    ("DST gap cannot be saved as an imaginary time", () => {
        var zone = TimeZoneInfo.FindSystemTimeZoneById("America/New_York");
        Throws<ArgumentException>(() => TaskRules.LocalDeadline(new DateTime(2026, 3, 8), "02:30", zone));
    }),
    ("Local files persist edits, category, due date and priority", () => WithStore((store, path) => {
        var task = store.Add("Первая\nвторая", TaskCategory.WorkID, stamp);
        store.Update(task.Id, t => t with { Priority = "high" });
        var loaded = new TaskStore(path);
        Check(loaded.Tasks.Single().Title == "Первая\nвторая" && loaded.Tasks.Single().FlameCount == 3 && loaded.Tasks.Single().DueDate == stamp);
    })),
    ("Priority updates do not reorder persisted data", () => WithStore((store, _) => {
        var first = store.Add("one"); var second = store.Add("two"); store.Update(second.Id, t => t with { Priority = "high" });
        Check(store.Tasks[0].Id == first.Id && TaskRules.Pending(store.Tasks).First().Id == second.Id);
        store.Update(second.Id, t => t with { Priority = "none" }); Check(TaskRules.Pending(store.Tasks).First().Id == first.Id);
    })),
    ("Completion and return preserve priority and text", () => WithStore((store, _) => {
        var task = store.Add("one"); store.Update(task.Id, t => t with { Priority = "high" }); store.Toggle(task.Id);
        Check(store.Tasks[0].IsCompleted && store.Tasks[0].FlameCount == 3); store.Toggle(task.Id);
        Check(!store.Tasks[0].IsCompleted && store.Tasks[0].Title == "one");
    })),
    ("Deleting a custom section keeps its tasks", () => WithStore((store, path) => {
        var category = store.AddCategory("Дом"); var task = store.Add("Задача", category.Id); store.DeleteCategory(category.Id);
        Check(store.Tasks.Single().Id == task.Id && store.Tasks.Single().CategoryID is null);
        Check(new TaskStore(path).Categories.All(c => c.Id != category.Id));
    })),
    ("System categories cannot be deleted", () => WithStore((store, _) => {
        Throws<ArgumentException>(() => store.DeleteCategory(TaskCategory.WorkID)); Throws<ArgumentException>(() => store.DeleteCategory(TaskCategory.PersonalID));
    })),
    ("Duplicate and blank categories rejected", () => WithStore((store, _) => {
        Throws<ArgumentException>(() => store.AddCategory(" работа ")); Throws<ArgumentException>(() => store.AddCategory(" "));
    })),
    ("Empty titles rejected without deleting data", () => WithStore((store, _) => {
        var task = store.Add("Task"); Throws<ArgumentException>(() => store.Add(" \n"));
        Throws<ArgumentException>(() => store.Update(task.Id, t => t with { Title = "" })); Check(store.Tasks[0].Title == "Task");
    })),
    ("Clear history does not remove unfinished tasks", () => WithStore((store, _) => {
        store.Add("pending"); var done = store.Add("done"); store.Toggle(done.Id); store.ClearHistory(); Check(store.Tasks.Single().Title == "pending");
    })),
    ("Category history filtering and clearing preserve other sections", () => WithStore((store, _) => {
        var family = store.AddCategory("Семья");
        var work = store.Add("Отчёт", TaskCategory.WorkID); store.Toggle(work.Id);
        var personal = store.Add("Отчёт", TaskCategory.PersonalID); store.Toggle(personal.Id);
        var custom = store.Add("Отчёт", family.Id); store.Toggle(custom.Id);
        var unfinished = store.Add("В работе", TaskCategory.WorkID);
        foreach (var category in new[] { TaskCategory.WorkID, TaskCategory.PersonalID, family.Id })
            Check(TaskRules.History(store.Tasks, TimeZoneInfo.Utc).Count(t => TaskRules.Matches(t, "отчет", category)) == 1);
        store.ClearHistory(TaskCategory.WorkID);
        Check(store.Tasks.Count == 3 && store.Tasks.Any(t => t.Id == unfinished.Id) && store.Tasks.Any(t => t.Id == personal.Id) && store.Tasks.Any(t => t.Id == custom.Id));
    })),
    ("Atomic writes preserve a previous backup", () => WithStore((store, path) => {
        store.Add("one"); store.Add("two"); Check(File.Exists(Path.Combine(path, "tasks.json.bak")));
        var previous = JsonSerializer.Deserialize<List<TodoItem>>(File.ReadAllText(Path.Combine(path, "tasks.json.bak")), TaskStore.JsonOptions)!;
        Check(previous.Count == 1 && previous[0].Title == "one"); Check(Directory.GetFiles(path, "*.tmp").Length == 0);
    })),
    ("Malformed storage fails closed and is not overwritten", () => WithDirectory(path => {
        File.WriteAllText(Path.Combine(path, "tasks.json"), "broken"); Throws<JsonException>(() => new TaskStore(path));
        Check(File.ReadAllText(Path.Combine(path, "tasks.json")) == "broken");
    })),
    ("Null storage is not interpreted as an empty list", () => WithDirectory(path => {
        File.WriteAllText(Path.Combine(path, "tasks.json"), "null"); Throws<InvalidDataException>(() => new TaskStore(path));
    })),
    ("Failed writes leave in-memory state unchanged", () => WithStore((store, path) => {
        Directory.CreateDirectory(Path.Combine(path, "tasks.json")); Throws<IOException>(() => store.Add("unsaved")); Check(store.Tasks.Count == 0);
    }))
};
var failures = 0;
foreach (var (name, test) in tests)
{
    try { test(); Console.WriteLine($"PASS {name}"); }
    catch (Exception exception) { failures++; Console.Error.WriteLine($"FAIL {name}: {exception}"); }
}
Console.WriteLine($"{tests.Length - failures}/{tests.Length} passed");
return failures == 0 ? 0 : 1;

TodoItem Item(string title, string priority = "none") => new() { Id = Guid.NewGuid(), Title = title, Priority = priority,
    CreatedAt = stamp, UpdatedAt = stamp, ScheduledFor = stamp };
void WithStore(Action<TaskStore, string> test) => WithDirectory(path => test(new TaskStore(path, () => stamp), path));
static void WithDirectory(Action<string> test)
{
    var directory = Path.Combine(Path.GetTempPath(), "today-core-tests-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(directory);
    try { test(directory); } finally { Directory.Delete(directory, recursive: true); }
}
static void Check(bool condition) { if (!condition) throw new Exception("Assertion failed"); }
static void Equal<T>(IEnumerable<T> actual, IEnumerable<T> expected) => Check(actual.SequenceEqual(expected));
static void Throws<T>(Action action) where T : Exception
{
    try { action(); } catch (T) { return; } throw new Exception($"Expected {typeof(T).Name}");
}
