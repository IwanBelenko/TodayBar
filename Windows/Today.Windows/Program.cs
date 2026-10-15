using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;
using Microsoft.Win32;
using Today.Core;
using Forms = System.Windows.Forms;
using Point = System.Drawing.Point;

namespace Today.Windows;

internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--smoke-test") return SmokeTests.Run(args[1]);
        using var mutex = new Mutex(true, @"Local\TodayBar.Windows.SingleInstance", out var first);
        if (!first)
        {
            try { using var wake = EventWaitHandle.OpenExisting(@"Local\TodayBar.Windows.Show"); wake.Set(); }
            catch (WaitHandleCannotBeOpenedException) { /* The first instance is still starting. */ }
            return 0;
        }
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        try
        {
            var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TodayBar");
            var store = new TaskStore(directory);
            using var tray = new TrayController(app, store);
            tray.Start(args.Contains("--startup"));
            app.Run();
            return 0;
        }
        catch (Exception exception)
        {
            MessageBox.Show("Today не удалось открыть. Сохранённые файлы не удалены.\n\n" + exception.Message,
                "Today", MessageBoxButton.OK, MessageBoxImage.Error);
            return 1;
        }
    }
}

internal sealed class TrayController : IDisposable
{
    private readonly Application app;
    private readonly TaskStore store;
    private readonly MainWindow window;
    private readonly Forms.NotifyIcon tray;
    private readonly Icon icon;
    private readonly DispatcherTimer hoverTimer = new() { Interval = TimeSpan.FromMilliseconds(250) };
    private readonly DispatcherTimer reminderTimer = new() { Interval = TimeSpan.FromSeconds(15) };
    private readonly HashSet<string> reminded = [];
    private readonly EventWaitHandle wake = new(false, EventResetMode.AutoReset, @"Local\TodayBar.Windows.Show");
    private readonly RegisteredWaitHandle wakeRegistration;
    private DateTimeOffset lastTrayMove = DateTimeOffset.MinValue;
    private DateTimeOffset suppressHoverUntil = DateTimeOffset.MinValue;
    private bool pinned, disposed;
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public TrayController(Application app, TaskStore store)
    {
        this.app = app; this.store = store;
        window = new MainWindow(store, Quit); app.MainWindow = window;
        icon = CreateIcon(); tray = new Forms.NotifyIcon { Icon = icon, Text = "Today — список дел", Visible = true };
        tray.MouseMove += (_, _) =>
        {
            lastTrayMove = DateTimeOffset.Now;
            if (!window.IsVisible && DateTimeOffset.Now > suppressHoverUntil) Show(false);
        };
        tray.MouseClick += (_, e) =>
        {
            if (e.Button != Forms.MouseButtons.Left) return;
            if (window.IsVisible && pinned) Hide(); else Show(true);
        };
        tray.BalloonTipClicked += (_, _) => Show(true);
        var menu = new Forms.ContextMenuStrip();
        var startup = new Forms.ToolStripMenuItem("Launch at Startup") { CheckOnClick = false };
        menu.Opening += (_, _) =>
        {
            try { startup.Checked = IsStartupEnabled(); }
            catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or IOException)
            { startup.Enabled = false; }
        };
        startup.Click += (_, _) =>
        {
            try
            {
                using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
                if (IsStartupEnabled()) key.DeleteValue("TodayBar", throwOnMissingValue: false);
                else key.SetValue("TodayBar", $"\"{Environment.ProcessPath}\" --startup");
            }
            catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or IOException)
            { MessageBox.Show("Не удалось изменить автозапуск. " + error.Message, "Today"); }
        };
        menu.Items.Add(new Forms.ToolStripMenuItem("Открыть Today", null, (_, _) => Show(true)));
        menu.Items.Add(startup); menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(new Forms.ToolStripMenuItem("Завершить Today", null, (_, _) => Quit()));
        tray.ContextMenuStrip = menu;
        menu.Opening += (_, _) => { suppressHoverUntil = DateTimeOffset.Now.AddSeconds(2); };
        menu.Closed += (_, _) => { suppressHoverUntil = DateTimeOffset.Now.AddSeconds(1); };
        window.Interacted += () => pinned = true;
        window.Deactivated += (_, _) =>
        {
            window.Dispatcher.BeginInvoke(() =>
            {
                if (!window.IsActive && !window.HasDialog && !window.HasOpenMenu) Hide();
            }, DispatcherPriority.Background);
        };
        hoverTimer.Tick += (_, _) =>
        {
            if (!pinned && window.IsVisible && !window.IsMouseOver && !window.HasDialog && !window.HasOpenMenu &&
                DateTimeOffset.Now - lastTrayMove > TimeSpan.FromSeconds(1.2)) Hide();
        };
        reminderTimer.Tick += (_, _) => CheckReminders();
        wakeRegistration = ThreadPool.RegisterWaitForSingleObject(wake, (_, _) => app.Dispatcher.BeginInvoke(() => Show(true)), null, Timeout.Infinite, false);
    }

    public void Start(bool startup)
    {
        hoverTimer.Start(); reminderTimer.Start();
        if (!startup) Show(true);
        CheckReminders();
    }
    private static bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue("TodayBar") is string command && command == $"\"{Environment.ProcessPath}\" --startup";
    }
    private void Show(bool activate)
    {
        pinned = activate;
        if (!window.IsVisible) { Ui.ApplyTheme(window); window.Refresh(); window.ShowActivated = activate; window.Show(); PositionWindow(); }
        if (activate) window.Activate();
    }
    private void Hide() { window.Hide(); pinned = false; suppressHoverUntil = DateTimeOffset.Now.AddMilliseconds(600); }
    private void Quit() { if (window.ConfirmQuit()) app.Shutdown(); }

    private void PositionWindow()
    {
        var point = Forms.Cursor.Position;
        var screen = Forms.Screen.FromPoint(point);
        var area = screen.WorkingArea;
        var handle = new WindowInteropHelper(window).Handle;
        var monitor = MonitorFromPoint(new NativePoint(point.X, point.Y), 2);
        uint dpi = 96;
        if (GetDpiForMonitor(monitor, 0, out var horizontal, out _) == 0) dpi = horizontal;
        var scale = dpi / 96.0;
        var width = Math.Min((int)(window.Width * scale), area.Width - 16);
        var height = Math.Min((int)(window.Height * scale), area.Height - 16);
        var left = Math.Clamp(point.X - width + 20, area.Left + 8, area.Right - width - 8);
        var top = point.Y < area.Top + area.Height / 2 ? area.Top + 8 : area.Bottom - height - 8;
        SetWindowPos(handle, IntPtr.Zero, left, top, width, height, 0x0014); // No activation / z-order change on hover.
    }
    private void CheckReminders()
    {
        var due = TaskRules.Pending(store.Tasks).Where(t => t.DueDate <= DateTimeOffset.Now &&
            !reminded.Contains($"{t.Id}:{t.DueDate:O}")).ToList();
        if (due.Count == 0) return;
        foreach (var task in due) reminded.Add($"{task.Id}:{task.DueDate:O}");
        var text = due.Count == 1 ? due[0].Title : $"Задач с истёкшим сроком: {due.Count}.\n" + due[0].Title;
        if (text.Length > 230) text = text[..227] + "…";
        tray.ShowBalloonTip(10000, "Срок задачи наступил", text, Forms.ToolTipIcon.Info);
        if (window.IsVisible && !window.IsKeyboardFocusWithin) window.Refresh();
    }
    private static Icon CreateIcon()
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        // Neutral icon stays legible on both light and dark Windows taskbars.
        graphics.FillEllipse(Brushes.DimGray, 1, 1, 30, 30);
        using var pen = new Pen(Color.White, 2.5f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        graphics.DrawEllipse(pen, 4, 4, 24, 24);
        graphics.DrawLines(pen, [new Point(10, 16), new Point(14, 21), new Point(22, 11)]);
        var handle = bitmap.GetHicon();
        try { using var original = Icon.FromHandle(handle); return (Icon)original.Clone(); }
        finally { DestroyIcon(handle); }
    }
    public void Dispose()
    {
        if (disposed) return; disposed = true;
        hoverTimer.Stop(); reminderTimer.Stop(); wakeRegistration.Unregister(null); wake.Dispose();
        tray.Visible = false; tray.ContextMenuStrip?.Dispose(); tray.Dispose(); icon.Dispose();
    }
    [StructLayout(LayoutKind.Sequential)] private readonly struct NativePoint(int x, int y) { public readonly int X = x, Y = y; }
    [DllImport("user32.dll")] private static extern bool DestroyIcon(IntPtr handle);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromPoint(NativePoint point, uint flags);
    [DllImport("shcore.dll")] private static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint x, out uint y);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr handle, IntPtr after, int x, int y, int width, int height, uint flags);
}
