using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Today.Core;

// The JSON contract matches Swift's ISO-8601 files, including UUIDs and categoryID spelling.
public sealed class TaskStore
{
    private readonly string directory;
    private readonly Func<DateTimeOffset> now;
    private List<TodoItem> tasks;
    private List<TaskCategory> categories;
    public IReadOnlyList<TodoItem> Tasks => tasks.AsReadOnly();
    public IReadOnlyList<TaskCategory> Categories => categories.AsReadOnly();
    public static JsonSerializerOptions JsonOptions { get; } = CreateOptions();

    public TaskStore(string directory, Func<DateTimeOffset>? now = null)
    {
        this.directory = directory;
        this.now = now ?? (() => DateTimeOffset.Now);
        tasks = Read<List<TodoItem>>("tasks.json") ?? [];
        categories = Read<List<TaskCategory>>("categories.json") ?? [];
        if (tasks.Any(t => t is null || t.Id == Guid.Empty || t.Title is null) || tasks.Select(t => t.Id).Distinct().Count() != tasks.Count ||
            categories.Any(c => c is null || c.Id == Guid.Empty || string.IsNullOrWhiteSpace(c.Name)) || categories.Select(c => c.Id).Distinct().Count() != categories.Count)
            throw new InvalidDataException("В файле задач или разделов есть повреждённые записи. Исходные файлы не изменены.");
        foreach (var category in TaskCategory.Defaults)
            if (categories.All(c => c.Id != category.Id)) categories.Add(category);
    }

    private T? Read<T>(string name)
    {
        var path = Path.Combine(directory, name);
        if (!File.Exists(path)) return default;
        return JsonSerializer.Deserialize<T>(File.ReadAllText(path), JsonOptions)
            ?? throw new InvalidDataException($"Файл {name} пуст или повреждён. Он не был перезаписан.");
    }

    private void Write<T>(string name, T value)
    {
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, name);
        var temporary = Path.Combine(directory, $".{name}.{Guid.NewGuid():N}.tmp");
        try
        {
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                JsonSerializer.Serialize(stream, value, JsonOptions);
                stream.Flush(flushToDisk: true);
            }
            if (File.Exists(path)) File.Replace(temporary, path, path + ".bak");
            else File.Move(temporary, path);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private void SaveTasks(List<TodoItem> replacement)
    {
        Write("tasks.json", replacement);
        tasks = replacement; // Do not show a successful mutation if saving failed.
    }

    public TodoItem Add(string title, Guid? categoryID = null, DateTimeOffset? dueDate = null)
    {
        title = title.Trim();
        if (title.Length == 0) throw new ArgumentException("Напишите задачу.");
        ValidateCategory(categoryID);
        var stamp = now();
        var task = new TodoItem { Id = Guid.NewGuid(), Title = title, CreatedAt = stamp, ScheduledFor = stamp,
            UpdatedAt = stamp, CategoryID = categoryID, DueDate = dueDate };
        SaveTasks([..tasks, task]);
        return task;
    }

    public void Update(Guid id, Func<TodoItem, TodoItem> change)
    {
        var index = tasks.FindIndex(t => t.Id == id);
        if (index < 0) throw new ArgumentException("Задача больше не существует.");
        var updated = change(tasks[index]) with { UpdatedAt = now() };
        if (updated.Id != id || string.IsNullOrWhiteSpace(updated.Title)) throw new ArgumentException("Текст задачи не может быть пустым.");
        if (updated.CategoryID != tasks[index].CategoryID) ValidateCategory(updated.CategoryID);
        var replacement = tasks.ToList();
        replacement[index] = updated;
        SaveTasks(replacement);
    }

    private void ValidateCategory(Guid? id)
    {
        if (id.HasValue && categories.All(c => c.Id != id)) throw new ArgumentException("Выберите существующий раздел.");
    }

    public void Toggle(Guid id) => Update(id, t => t with { CompletedAt = t.IsCompleted ? null : now() });
    public void Delete(Guid id) => SaveTasks(tasks.Where(t => t.Id != id).ToList());
    public void ClearHistory(Guid? categoryID = null) => SaveTasks(tasks.Where(t => !t.IsCompleted ||
        (categoryID.HasValue && t.CategoryID != categoryID)).ToList());
    public TaskCategory? Category(Guid? id) => categories.FirstOrDefault(c => c.Id == id);

    public TaskCategory AddCategory(string name)
    {
        name = name.Trim();
        if (name.Length == 0 || name.Length > 60) throw new ArgumentException("Название раздела — от 1 до 60 символов.");
        if (categories.Any(c => TaskRules.Normalize(c.Name) == TaskRules.Normalize(name))) throw new ArgumentException("Такой раздел уже есть.");
        var category = new TaskCategory(Guid.NewGuid(), name);
        var replacement = categories.Append(category).ToList();
        Write("categories.json", replacement);
        categories = replacement;
        return category;
    }

    public void DeleteCategory(Guid id)
    {
        if (Category(id)?.IsSystem != false) throw new ArgumentException("Этот раздел нельзя удалить.");
        // Save references first: interruption cannot leave tasks pointing at a deleted category.
        SaveTasks(tasks.Select(t => t.CategoryID == id ? t with { CategoryID = null, UpdatedAt = now() } : t).ToList());
        var replacement = categories.Where(c => c.Id != id).ToList();
        Write("categories.json", replacement);
        categories = replacement;
    }

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull };
        options.Converters.Add(new SwiftDateConverter());
        return options;
    }

    private sealed class SwiftDateConverter : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options) => reader.GetDateTimeOffset();
        public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
            writer.WriteStringValue(value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture));
    }
}
