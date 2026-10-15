using System;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Today.Core;

namespace Today.Windows;

// Explicit test mode only: no tray, startup registry, notifications or personal data.
internal static class SmokeTests
{
    internal static int Run(string output)
    {
        var data = Path.Combine(Path.GetTempPath(), "today-ui-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(data); Directory.CreateDirectory(output);
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        try
        {
            var store = new TaskStore(data);
            var none = store.Add("Купить новую книгу", TaskCategory.PersonalID);
            var low = store.Add("Записаться на тренировку", TaskCategory.PersonalID);
            store.Update(low.Id, t => t with { Priority = "low" });
            var medium = store.Add("Обсудить с командой\nследующий этап проекта", TaskCategory.WorkID);
            store.Update(medium.Id, t => t with { Priority = "medium" });
            var high = store.Add("Подготовить план на неделю", TaskCategory.WorkID, DateTimeOffset.Now.AddDays(1));
            store.Update(high.Id, t => t with { Priority = "high" });
            var completed = store.Add("Отправить отчёт", TaskCategory.WorkID); store.Toggle(completed.Id);
            var personalDone = store.Add("Семейный ужин", TaskCategory.PersonalID); store.Toggle(personalDone.Id);
            var family = store.AddCategory("Семья");
            var familyDone = store.Add("Позвонить родителям", family.Id); store.Toggle(familyDone.Id);
            var window = new MainWindow(store, () => { }); window.Show(); Pump();
            Check(window.VisibleTaskIDs.Take(4).SequenceEqual(new[] { high.Id, medium.Id, low.Id, none.Id }), "priority ordering");
            Capture(window, output, "today-light", false); Capture(window, output, "today-dark", true);
            window.Search.Text = "КОМАНДОЙ этап"; Pump(); Check(window.VisibleTaskIDs.SequenceEqual(new[] { medium.Id }), "multiline search");
            Capture(window, output, "search", false);
            window.SetHistory(true); window.Search.Text = "отчет"; Pump(); Check(window.VisibleTaskIDs.SequenceEqual(new[] { completed.Id }), "history search");
            Capture(window, output, "history", false);
            window.Search.Clear(); window.SetCategory(TaskCategory.PersonalID); Pump();
            Check(window.VisibleTaskIDs.SequenceEqual(new[] { personalDone.Id }) && window.PendingCount == 2 && window.CompletedCount == 1, "personal history and counters");
            window.SetCategory(family.Id); Pump();
            Check(window.VisibleTaskIDs.SequenceEqual(new[] { familyDone.Id }), "custom section history");
            Capture(window, output, "history-family", true);
            window.SetHistory(false); window.SetHistory(true); Pump();
            Check(window.VisibleTaskIDs.SequenceEqual(new[] { familyDone.Id }), "section survives tab switching");
            window.SetCategory(null); Pump(); Check(window.VisibleTaskIDs.Count == 3, "all history");
            window.SetHistory(false); window.Search.Clear();
            var menu = window.TaskMenu(none.Id);
            var highPriority = (MenuItem)((MenuItem)menu.Items[0]).Items[3];
            highPriority.RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent)); Pump();
            Check(store.Tasks.First(t => t.Id == none.Id).FlameCount == 3 && window.VisibleTaskIDs[0] == none.Id, "priority menu action");
            window.Composer.Text = "Первая строка\nВторая строка"; window.AddTask(); Pump();
            Check(store.Tasks.Last().Title == "Первая строка\nВторая строка" && window.Composer.Text == "", "composer submission");
            var clipboardMenu = window.TaskMenu(medium.Id);
            var copy = clipboardMenu.Items.OfType<MenuItem>().Single(item => (string)item.Header == "Скопировать задачу");
            copy.RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent)); Check(Clipboard.GetText() == medium.Title, "native clipboard");
            var deadline = new DeadlineWindow(null) { Owner = window }; deadline.Show(); Pump();
            deadline.TimeField.Text = "14:35"; Check(deadline.TimeField.Text == "14:35", "editable time");
            Capture(deadline, output, "calendar-light", false); Capture(deadline, output, "calendar-dark", true); deadline.Close();
            Console.WriteLine("PASS Windows UI: startup, themes, sorting, search, history, menu action, composer, clipboard, calendar");
            app.Shutdown(); return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error); app.Shutdown(); return 1; }
        finally { Directory.Delete(data, recursive: true); }
    }
    private static void Capture(Window window, string output, string name, bool dark)
    {
        Ui.ApplyTheme(window, dark); Pump(); window.UpdateLayout();
        var bitmap = new RenderTargetBitmap((int)Math.Ceiling(window.ActualWidth), (int)Math.Ceiling(window.ActualHeight), 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(window);
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(Path.Combine(output, name + ".png")); encoder.Save(stream);
    }
    private static void Pump() => Application.Current.Dispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
    private static void Check(bool condition, string label) { if (!condition) throw new InvalidOperationException("Failed: " + label); }
}
