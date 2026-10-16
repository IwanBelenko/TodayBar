using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Today.Core;
using Forms = System.Windows.Forms;

namespace Today.Windows;

// Explicit test mode only: no tray, startup registry, notifications or personal data.
internal static class SmokeTests
{
    internal static int Run(string output)
    {
        var data = Path.Combine(Path.GetTempPath(), "today-ui-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(data); Directory.CreateDirectory(output);
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var originalCulture = CultureInfo.CurrentUICulture;
        var outputRoot = output;
        try
        {
            CheckTrayActivation();
            foreach (var language in new[] { "ru-RU", "en-US" })
            {
                CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(language);
                output = Path.Combine(outputRoot, language);
                Directory.CreateDirectory(output);
                var store = new TaskStore(Path.Combine(data, language));
                var none = store.Add(I18n.Text("Купить новую книгу", "Buy a new book"), TaskCategory.PersonalID);
                var low = store.Add(I18n.Text("Записаться на тренировку", "Book a workout"), TaskCategory.PersonalID);
                store.Update(low.Id, t => t with { Priority = "low" });
                var medium = store.Add(I18n.Text("Обсудить с командой\nследующий этап проекта", "Discuss the next project phase\nwith the team"), TaskCategory.WorkID);
                store.Update(medium.Id, t => t with { Priority = "medium" });
                var high = store.Add(I18n.Text("Подготовить план на неделю", "Plan the week"), TaskCategory.WorkID, DateTimeOffset.Now.AddDays(1));
                store.Update(high.Id, t => t with { Priority = "high" });
                var completed = store.Add(I18n.Text("Отправить отчёт", "Send the report"), TaskCategory.WorkID); store.Toggle(completed.Id);
                var personalDone = store.Add(I18n.Text("Семейный ужин", "Family dinner"), TaskCategory.PersonalID); store.Toggle(personalDone.Id);
                var family = store.AddCategory(I18n.Text("Семья", "Family"));
                var familyDone = store.Add(I18n.Text("Позвонить родителям", "Call my parents"), family.Id); store.Toggle(familyDone.Id);
                var window = new MainWindow(store, () => { }); window.Show(); Pump();
                Check(window.VisibleTaskIDs.Take(4).SequenceEqual(new[] { high.Id, medium.Id, low.Id, none.Id }), "priority ordering");
                Capture(window, output, "today-light", false); Capture(window, output, "today-dark", true);
                window.Search.Text = I18n.Text("КОМАНДОЙ этап", "TEAM phase"); Pump(); Check(window.VisibleTaskIDs.SequenceEqual(new[] { medium.Id }), "multiline search");
                Capture(window, output, "search", false);
                window.SetHistory(true); window.Search.Text = I18n.Text("отчет", "report"); Pump(); Check(window.VisibleTaskIDs.SequenceEqual(new[] { completed.Id }), "history search");
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
                var copy = clipboardMenu.Items.OfType<MenuItem>().Single(item => (string)item.Header == I18n.Text("Скопировать задачу", "Copy task"));
                copy.RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent)); Check(Clipboard.GetText() == medium.Title, "native clipboard");
                var deadline = new DeadlineWindow(null) { Owner = window }; deadline.Show(); Pump();
                deadline.TimeField.Text = "14:35"; Check(deadline.TimeField.Text == "14:35", "editable time");
                Capture(deadline, output, "calendar-light", false); Capture(deadline, output, "calendar-dark", true); deadline.Close();
                window.Hide();
                Console.WriteLine("PASS UI language: " + language);
            }
            Console.WriteLine("PASS Windows UI: click-only tray activation, startup, themes, sorting, search, history, menu action, composer, clipboard, calendar");
            app.Shutdown(); return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error); app.Shutdown(); return 1; }
        finally { CultureInfo.CurrentUICulture = originalCulture; Directory.Delete(data, recursive: true); }
    }
    private static void CheckTrayActivation()
    {
        // Exercise the real event bindings without installing an icon in the system tray.
        using var tray = new Forms.NotifyIcon { Visible = false };
        var visible = false;
        var toggles = 0;
        var shows = 0;
        TrayController.BindActivation(tray, () => { visible = !visible; toggles++; }, () => { visible = true; shows++; });
        void Raise(string name, params object[] args)
        {
            // NotifyIcon is sealed; its private On... methods raise the native component's events.
            var method = typeof(Forms.NotifyIcon).GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic)
                ?? throw new InvalidOperationException("NotifyIcon event method missing: " + name);
            method.Invoke(tray, args);
        }
        var move = new Forms.MouseEventArgs(Forms.MouseButtons.None, 0, 0, 0, 0);
        var left = new Forms.MouseEventArgs(Forms.MouseButtons.Left, 1, 0, 0, 0);
        for (var i = 0; i < 5; i++) Raise("OnMouseMove", move);
        Check(!visible && toggles == 0 && shows == 0, "hover must not open Today");
        Raise("OnMouseClick", new Forms.MouseEventArgs(Forms.MouseButtons.Right, 1, 0, 0, 0));
        Check(!visible && toggles == 0, "right click must not open the task window");
        Raise("OnMouseClick", left);
        Check(visible && toggles == 1, "left click opens Today");
        Raise("OnMouseMove", move);
        Check(visible && toggles == 1 && shows == 0, "hover must not change an open window");
        Raise("OnMouseClick", left);
        Raise("OnMouseMove", move);
        Check(!visible && toggles == 2 && shows == 0, "hover must not reopen a closed window");
        Raise("OnBalloonTipClicked");
        Check(visible && shows == 1, "notification click still opens Today");
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
