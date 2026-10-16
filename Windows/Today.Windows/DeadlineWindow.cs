using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Today.Core;

namespace Today.Windows;

internal sealed class DeadlineWindow : Window
{
    private DateTime selected, month;
    private readonly System.Windows.Controls.Primitives.UniformGrid days = new() { Columns = 7, Rows = 6 };
    private readonly TextBlock monthLabel = Ui.Text("", 17), feedback = Ui.Text("", 13, "Muted");
    internal readonly TextBox TimeField = new() { FontSize = 30, FontFamily = new FontFamily("Consolas"), TextAlignment = TextAlignment.Center, MaxLength = 5 };
    internal DateTimeOffset? Value { get; private set; }

    internal DeadlineWindow(DateTimeOffset? initial)
    {
        selected = (initial?.LocalDateTime ?? DateTime.Today.AddDays(1).AddHours(9)).Date;
        month = new DateTime(selected.Year, selected.Month, 1);
        TimeField.Text = (initial?.LocalDateTime ?? DateTime.Today.AddHours(9)).ToString("HH:mm");
        Title = I18n.Text("Дата и время", "Date and time"); Width = 360; SizeToContent = SizeToContent.Height;
        WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.NoResize; ShowInTaskbar = false;
        AllowsTransparency = true; Background = Brushes.Transparent; WindowStartupLocation = WindowStartupLocation.CenterOwner;
        FontFamily = new FontFamily("Segoe UI"); Ui.ApplyTheme(this);
        var body = new StackPanel { Margin = new Thickness(20) };
        var heading = new DockPanel();
        var cancel = Ui.Button("×", I18n.Text("Закрыть календарь", "Close calendar"), () => DialogResult = false);
        DockPanel.SetDock(cancel, Dock.Right); heading.Children.Add(cancel);
        var title = Ui.Text(I18n.Text("Дата и время", "Date and time"), 21); title.FontWeight = FontWeights.SemiBold; heading.Children.Add(title); body.Children.Add(heading);
        var shortcuts = new System.Windows.Controls.Primitives.UniformGrid { Columns = 3, Margin = new Thickness(0, 12, 0, 14) };
        foreach (var (label, offset) in new[] { (I18n.Text("Сегодня", "Today"), 0), (I18n.Text("Завтра", "Tomorrow"), 1), (I18n.Text("+ Неделя", "+ Week"), 7) })
            shortcuts.Children.Add(Ui.Button(label, label, () => Select(DateTime.Today.AddDays(offset))));
        body.Children.Add(shortcuts);
        var navigation = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
        var next = Ui.Button("›", I18n.Text("Следующий месяц", "Next month"), () => { month = month.AddMonths(1); RenderDays(); });
        var previous = Ui.Button("‹", I18n.Text("Предыдущий месяц", "Previous month"), () => { month = month.AddMonths(-1); RenderDays(); });
        DockPanel.SetDock(next, Dock.Right); DockPanel.SetDock(previous, Dock.Right); navigation.Children.Add(next); navigation.Children.Add(previous); navigation.Children.Add(monthLabel); body.Children.Add(navigation);
        var weekdays = new System.Windows.Controls.Primitives.UniformGrid { Columns = 7 };
        foreach (var name in new[] { I18n.Text("Пн", "Mon"), I18n.Text("Вт", "Tue"), I18n.Text("Ср", "Wed"), I18n.Text("Чт", "Thu"), I18n.Text("Пт", "Fri"), I18n.Text("Сб", "Sat"), I18n.Text("Вс", "Sun") })
        { var label = Ui.Text(name, 12, "Muted"); label.HorizontalAlignment = HorizontalAlignment.Center; weekdays.Children.Add(label); }
        body.Children.Add(weekdays); body.Children.Add(days);
        var separator = Ui.Line(); separator.Margin = new Thickness(0, 14, 0, 12); body.Children.Add(separator);
        body.Children.Add(Ui.Text(I18n.Text("Время", "Time"), 14, "Muted"));
        var clock = new Grid { Margin = new Thickness(0, 8, 0, 6) };
        clock.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(44) }); clock.ColumnDefinitions.Add(new ColumnDefinition()); clock.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(44) });
        clock.Children.Add(Ui.Button("−", I18n.Text("На 15 минут раньше", "15 minutes earlier"), () => Step(-15)));
        var field = Ui.Card(TimeField, 12); field.Margin = new Thickness(8, 0, 8, 0); Grid.SetColumn(field, 1); clock.Children.Add(field);
        Ui.Name(TimeField, I18n.Text("Время в формате ЧЧ:ММ", "Time in HH:MM format")); TimeField.ToolTip = I18n.Text("Введите время вручную, например 14:30", "Type a time, for example 14:30");
        var plus = Ui.Button("+", I18n.Text("На 15 минут позже", "15 minutes later"), () => Step(15)); Grid.SetColumn(plus, 2); clock.Children.Add(plus); body.Children.Add(clock);
        feedback.TextWrapping = TextWrapping.Wrap; feedback.Margin = new Thickness(0, 8, 0, 12); body.Children.Add(feedback);
        var bottom = new DockPanel();
        var done = Ui.Button(I18n.Text("Готово", "Done"), I18n.Text("Сохранить дату и время", "Save date and time"), Save); done.IsDefault = true; done.SetResourceReference(BackgroundProperty, "Hover");
        DockPanel.SetDock(done, Dock.Right); bottom.Children.Add(done);
        if (initial.HasValue) bottom.Children.Add(Ui.Button(I18n.Text("Убрать срок", "Remove due date"), I18n.Text("Убрать срок задачи", "Remove task due date"), () => { Value = null; DialogResult = true; }));
        body.Children.Add(bottom); Content = Ui.Card(body, 24, "Surface");
        PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) { DialogResult = false; e.Handled = true; } };
        RenderDays();
    }

    private void Select(DateTime value) { selected = value.Date; month = new DateTime(value.Year, value.Month, 1); RenderDays(); }
    private void RenderDays()
    {
        monthLabel.Text = month.ToString("MMMM yyyy", I18n.Culture); days.Children.Clear();
        var start = month.AddDays(-(((int)month.DayOfWeek + 6) % 7));
        for (var index = 0; index < 42; index++)
        {
            var day = start.AddDays(index);
            var button = Ui.Button(day.Day.ToString(), day.ToString("D", I18n.Culture), () => Select(day));
            button.Padding = new Thickness(0); button.Height = 32; button.Margin = new Thickness(1);
            if (day.Month != month.Month) button.SetResourceReference(ForegroundProperty, "Muted");
            if (day == selected) { button.SetResourceReference(BackgroundProperty, "Hover"); button.SetResourceReference(BorderBrushProperty, "Ink"); }
            else if (day == DateTime.Today) button.SetResourceReference(BorderBrushProperty, "Line");
            days.Children.Add(button);
        }
        feedback.Text = selected.ToString("d MMMM yyyy", I18n.Culture) + I18n.Text(" · время можно ввести вручную", " · type a time below");
    }
    private void Step(int minutes)
    {
        try
        {
            var value = TaskRules.LocalDeadline(selected, TimeField.Text, TimeZoneInfo.Local).AddMinutes(minutes).LocalDateTime;
            TimeField.Text = value.ToString("HH:mm"); Select(value);
        }
        catch (ArgumentException exception) { feedback.Text = exception.Message; }
    }
    private void Save()
    {
        try { Value = TaskRules.LocalDeadline(selected, TimeField.Text, TimeZoneInfo.Local); DialogResult = true; }
        catch (ArgumentException exception) { feedback.Text = exception.Message; TimeField.Focus(); }
    }
}

internal sealed class TextPrompt : Window
{
    private readonly TextBox input = new() { MaxLength = 60, Margin = new Thickness(8), MinHeight = 30 };
    public string Value => input.Text;
    public TextPrompt()
    {
        Title = I18n.Text("Новый раздел", "New category"); Width = 340; SizeToContent = SizeToContent.Height; ResizeMode = ResizeMode.NoResize;
        WindowStyle = WindowStyle.None; AllowsTransparency = true; Background = Brushes.Transparent;
        ShowInTaskbar = false; WindowStartupLocation = WindowStartupLocation.CenterOwner; FontFamily = new FontFamily("Segoe UI"); Ui.ApplyTheme(this);
        var body = new StackPanel { Margin = new Thickness(20) };
        body.Children.Add(Ui.Text(I18n.Text("Новый раздел", "New category"), 22));
        var field = Ui.Card(input, 12); field.Margin = new Thickness(0, 16, 0, 12); body.Children.Add(field); Ui.Name(input, I18n.Text("Название раздела", "Category name"));
        var actions = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        actions.Children.Add(Ui.Button(I18n.Text("Отмена", "Cancel"), I18n.Text("Отмена", "Cancel"), () => DialogResult = false));
        var add = Ui.Button(I18n.Text("Добавить", "Add"), I18n.Text("Добавить раздел", "Add category"), () => { if (!string.IsNullOrWhiteSpace(Value)) DialogResult = true; });
        add.IsDefault = true; actions.Children.Add(add); body.Children.Add(actions); Content = Ui.Card(body, 24, "Surface");
        Loaded += (_, _) => input.Focus();
        PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) DialogResult = false; };
    }
}
