using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using Today.Core;

namespace Today.Windows;

internal sealed class MainWindow : Window
{
    private readonly TaskStore store;
    private readonly Action quit;
    internal readonly TextBox Search = new() { FontSize = 14, VerticalContentAlignment = VerticalAlignment.Center };
    internal readonly TextBox Composer = new() { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap,
        MinHeight = 46, MaxHeight = 120, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    private readonly StackPanel rows = new(), categories = new() { Orientation = Orientation.Horizontal };
    private readonly TextBlock error = Ui.Text("", 13), footer = Ui.Text("На этом ПК", 13, "Muted"), progress = Ui.Text("", 13, "Muted");
    private readonly Button todayButton, historyButton, composeCategory, composeDue, addButton;
    private readonly TextBlock date = Ui.Text("", 14, "Muted");
    private readonly ScrollViewer list;
    private readonly Dictionary<Guid, string> drafts = [];
    private Guid? selectedCategory, newCategory = TaskCategory.WorkID;
    private DateTimeOffset? newDue;
    private bool history, completedExpanded = true, rendering;
    internal bool HasOpenMenu { get; private set; }
    internal bool HasDialog { get; private set; }
    internal event Action? Interacted;
    internal IReadOnlyList<Guid> VisibleTaskIDs { get; private set; } = [];
    internal int PendingCount => store.Tasks.Count(t => !t.IsCompleted && TaskRules.Matches(t, "", selectedCategory));
    internal int CompletedCount => TaskRules.CompletedToday(store.Tasks, DateTimeOffset.Now, TimeZoneInfo.Local).Count(t => TaskRules.Matches(t, "", selectedCategory));

    internal MainWindow(TaskStore store, Action quit)
    {
        this.store = store;
        this.quit = quit;
        Title = "Today";
        Width = 440; Height = 660;
        MinWidth = 380; MinHeight = 420;
        FontFamily = new FontFamily("Segoe UI");
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        Ui.ApplyTheme(this);
        var root = new Grid { Margin = new Thickness(18, 18, 18, 12) };
        foreach (var height in new[] { GridLength.Auto, GridLength.Auto, GridLength.Auto, new GridLength(1, GridUnitType.Star), GridLength.Auto, GridLength.Auto, GridLength.Auto })
            root.RowDefinitions.Add(new RowDefinition { Height = height });
        var shell = Ui.Card(root, 30, "Surface");
        Content = shell; // Transparent HWND + a real rounded surface, not a shadow imitation.

        var header = new Grid { Margin = new Thickness(0, 0, 0, 14) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(46) });
        header.ColumnDefinitions.Add(new ColumnDefinition());
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(132) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(34) });
        var mark = Ui.Card(Ui.Text("✓", 26), 15, "Hover");
        mark.Width = 38; mark.Height = 42; mark.HorizontalAlignment = HorizontalAlignment.Left;
        ((TextBlock)mark.Child).HorizontalAlignment = HorizontalAlignment.Center;
        header.Children.Add(mark);
        var heading = new StackPanel { Margin = new Thickness(4, 0, 4, 0) };
        var title = Ui.Text("Сегодня", 25); title.FontWeight = FontWeights.SemiBold;
        heading.Children.Add(title); heading.Children.Add(date);
        Grid.SetColumn(heading, 1); header.Children.Add(heading);
        var searchGrid = new Grid();
        searchGrid.ColumnDefinitions.Add(new ColumnDefinition());
        searchGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(26) });
        Search.ToolTip = "Поиск задач · Ctrl+F"; Ui.Name(Search, "Поиск задач");
        searchGrid.Children.Add(Search);
        var searchHint = Ui.Text("⌕ Поиск задач", 13, "Muted"); searchHint.IsHitTestVisible = false;
        searchGrid.Children.Add(searchHint);
        var clearSearch = Ui.Button("×", "Очистить поиск", () => Search.Clear());
        clearSearch.Visibility = Visibility.Collapsed;
        clearSearch.Padding = new Thickness(0); Grid.SetColumn(clearSearch, 1); searchGrid.Children.Add(clearSearch);
        var searchCard = Ui.Card(searchGrid, 10); searchCard.Height = 34; searchCard.Padding = new Thickness(7, 0, 0, 0);
        Grid.SetColumn(searchCard, 2); header.Children.Add(searchCard);
        var appMenu = Ui.Button("⋯", "Меню приложения", () => OpenMenu(BuildAppMenu(), header));
        appMenu.Padding = new Thickness(0); Grid.SetColumn(appMenu, 3); header.Children.Add(appMenu);
        root.Children.Add(header);

        var tabs = new Grid { Margin = new Thickness(0, 0, 0, 8) };
        tabs.ColumnDefinitions.Add(new ColumnDefinition()); tabs.ColumnDefinitions.Add(new ColumnDefinition());
        tabs.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        todayButton = Ui.Button("Сегодня", "Задачи на сегодня", () => SetHistory(false));
        historyButton = Ui.Button("История", "История выполненных задач", () => SetHistory(true));
        todayButton.FontSize = historyButton.FontSize = 17;
        tabs.Children.Add(todayButton); Grid.SetColumn(historyButton, 1); tabs.Children.Add(historyButton);
        progress.Margin = new Thickness(12, 0, 2, 0); Grid.SetColumn(progress, 2); tabs.Children.Add(progress);
        Put(root, tabs, 1);
        var categoryScroll = new ScrollViewer { Content = categories, HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled, Margin = new Thickness(0, 0, 0, 8), MaxHeight = 60 };
        Put(root, categoryScroll, 2);
        list = new ScrollViewer { Content = rows, VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Margin = new Thickness(-4, 0, -4, 12), Padding = new Thickness(0, 0, 4, 0) };
        Put(root, list, 3);

        var composerGrid = new Grid { Margin = new Thickness(12) };
        composerGrid.RowDefinitions.Add(new RowDefinition()); composerGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        composerGrid.ColumnDefinitions.Add(new ColumnDefinition()); composerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(36) });
        Composer.ToolTip = "Новое дело. Enter — добавить, Shift+Enter — новая строка"; Ui.Name(Composer, "Новое дело");
        composerGrid.Children.Add(Composer);
        var composerHint = Ui.Text("＋ Новое дело…", 17, "Muted"); composerHint.VerticalAlignment = VerticalAlignment.Top;
        composerHint.Margin = new Thickness(2, 2, 0, 0); composerHint.IsHitTestVisible = false; composerGrid.Children.Add(composerHint);
        addButton = Ui.Button("↑", "Добавить задачу", AddTask); addButton.FontSize = 22; addButton.Padding = new Thickness(0);
        addButton.Height = 34; addButton.VerticalAlignment = VerticalAlignment.Top;
        addButton.SetResourceReference(BackgroundProperty, "Hover");
        Grid.SetColumn(addButton, 1); composerGrid.Children.Add(addButton);
        var toolbar = new Grid { Margin = new Thickness(0, 10, 0, 0) };
        toolbar.ColumnDefinitions.Add(new ColumnDefinition()); toolbar.ColumnDefinitions.Add(new ColumnDefinition());
        composeCategory = Ui.Button("Работа", "Раздел новой задачи", () => OpenMenu(CategoryMenu(id => { newCategory = id; UpdateComposer(); }), composeCategory!));
        composeDue = Ui.Button("＋ Срок", "Срок новой задачи", () => PickDue(newDue, due => { newDue = due; UpdateComposer(); }));
        composeCategory.FontSize = composeDue.FontSize = 14;
        toolbar.Children.Add(composeCategory); Grid.SetColumn(composeDue, 1); toolbar.Children.Add(composeDue);
        Grid.SetRow(toolbar, 1); Grid.SetColumnSpan(toolbar, 2); composerGrid.Children.Add(toolbar);
        var composerCard = Ui.Card(composerGrid, 22); Put(root, composerCard, 4);
        var hint = Ui.Text("Enter — добавить     Shift+Enter — новая строка", 12, "Muted");
        hint.Margin = new Thickness(4, 7, 0, 8); Put(root, hint, 5);
        var bottom = new StackPanel(); bottom.Children.Add(Ui.Line());
        error.TextWrapping = TextWrapping.Wrap; error.Margin = new Thickness(0, 8, 0, 0); error.Visibility = Visibility.Collapsed;
        bottom.Children.Add(error); footer.Margin = new Thickness(4, 9, 0, 0); bottom.Children.Add(footer); Put(root, bottom, 6);

        Search.TextChanged += (_, _) => {
            searchHint.Visibility = Search.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
            clearSearch.Visibility = Search.Text.Length == 0 ? Visibility.Collapsed : Visibility.Visible;
            RenderRows();
        };
        Search.PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) { Search.Clear(); e.Handled = true; } };
        Composer.TextChanged += (_, _) => {
            addButton.IsEnabled = !string.IsNullOrWhiteSpace(Composer.Text);
            composerHint.Visibility = Composer.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
        };
        Composer.PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Enter && !Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) { AddTask(); e.Handled = true; }
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.F && Keyboard.Modifiers.HasFlag(ModifierKeys.Control)) { Search.Focus(); Search.SelectAll(); e.Handled = true; }
            else if (e.Key == Key.Escape && !HasDialog && !HasOpenMenu) { Hide(); e.Handled = true; }
        };
        PreviewMouseDown += (_, _) => Interacted?.Invoke();
        PreviewKeyDown += (_, _) => Interacted?.Invoke();
        Closing += (_, e) => { e.Cancel = true; Hide(); };
        Refresh();
    }

    private static void Put(Grid grid, UIElement child, int row) { Grid.SetRow(child, row); grid.Children.Add(child); }
    internal void SetHistory(bool value) { history = value; Refresh(); }
    internal void SetCategory(Guid? value) { selectedCategory = value; if (value.HasValue) newCategory = value; Refresh(); }

    internal void Refresh()
    {
        date.Text = DateTime.Now.ToString("dddd, d MMM", CultureInfo.GetCultureInfo("ru-RU"));
        todayButton.Content = $"Сегодня {PendingCount}";
        todayButton.SetResourceReference(BackgroundProperty, history ? "Surface" : "Hover");
        historyButton.SetResourceReference(BackgroundProperty, history ? "Hover" : "Surface");
        var done = CompletedCount;
        progress.Text = $"{done} из {PendingCount + done}";
        var overdue = store.Tasks.Count(t => !t.IsCompleted && t.DueDate < DateTimeOffset.Now && TaskRules.Matches(t, "", selectedCategory));
        footer.Text = overdue > 0 ? $"Просрочено: {overdue}   ·   На этом ПК" : "На этом ПК                                 Today";
        categories.Children.Clear();
        AddCategoryChip(null, "Все");
        foreach (var category in store.Categories) AddCategoryChip(category.Id, category.Name);
        categories.Children.Add(Ui.Button("+", "Новый раздел", AddCategory));
        UpdateComposer(); RenderRows();
    }

    private void AddCategoryChip(Guid? id, string name)
    {
        var chip = Ui.Button(name, name, () => SetCategory(id));
        chip.Margin = new Thickness(0, 0, 4, 0);
        if (id == selectedCategory) chip.SetResourceReference(BackgroundProperty, "Hover");
        if (store.Category(id)?.IsSystem == false)
        {
            var menu = new ContextMenu(); Ui.ApplyTheme(menu);
            menu.Items.Add(Ui.Menu("Удалить раздел…", () =>
            {
                HasDialog = true;
                var confirmed = MessageBox.Show(this, $"Удалить раздел «{name}»? Задачи останутся в «Все».", "Today", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
                HasDialog = false;
                if (confirmed) Run(() => { store.DeleteCategory(id!.Value); if (selectedCategory == id) selectedCategory = null; if (newCategory == id) newCategory = TaskCategory.WorkID; });
            }));
            TrackMenu(menu); chip.ContextMenu = menu;
        }
        categories.Children.Add(chip);
    }

    private void RenderRows()
    {
        if (rendering) return;
        rendering = true;
        try
        {
            var offset = list.VerticalOffset;
            rows.Children.Clear();
            var matches = store.Tasks.Where(t => TaskRules.Matches(t, Search.Text, selectedCategory)).ToList();
            var visible = new List<Guid>();
            if (history)
            {
                foreach (var group in TaskRules.History(matches, TimeZoneInfo.Local).GroupBy(t => TaskRules.LocalDay(t.CompletedAt!.Value, TimeZoneInfo.Local)))
                {
                    var label = Ui.Text(group.Key.ToString("d MMMM yyyy", CultureInfo.GetCultureInfo("ru-RU")), 14, "Muted");
                    label.Margin = new Thickness(10, 12, 0, 8); rows.Children.Add(label);
                    foreach (var task in group) { rows.Children.Add(TaskRow(task)); visible.Add(task.Id); }
                }
                if (visible.Count > 0 && string.IsNullOrWhiteSpace(Search.Text))
                    rows.Children.Add(Ui.Button("Очистить историю…", "Удалить выполненные задачи выбранного раздела", () =>
                    {
                        HasDialog = true;
                        var message = selectedCategory.HasValue ? $"Удалить выполненные задачи из «{store.Category(selectedCategory)?.Name}»? История остальных разделов сохранится." : "Удалить все выполненные задачи? Это действие нельзя отменить.";
                        var yes = MessageBox.Show(this, message, "Today", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
                        HasDialog = false;
                        if (yes) Run(() => store.ClearHistory(selectedCategory));
                    }));
            }
            else
            {
                foreach (var task in TaskRules.Pending(matches)) { rows.Children.Add(TaskRow(task)); visible.Add(task.Id); }
                var completed = TaskRules.CompletedToday(matches, DateTimeOffset.Now, TimeZoneInfo.Local).ToList();
                if (completed.Count > 0)
                {
                    rows.Children.Add(Ui.Button($"{(completedExpanded ? "⌄" : "›")} Выполнено · {completed.Count}", "Показать или скрыть выполненные", () => { completedExpanded = !completedExpanded; RenderRows(); }));
                    if (completedExpanded || !string.IsNullOrWhiteSpace(Search.Text))
                        foreach (var task in completed) { rows.Children.Add(TaskRow(task)); visible.Add(task.Id); }
                }
            }
            VisibleTaskIDs = visible;
            if (visible.Count == 0 && !(rows.Children.Count > 0))
            {
                var empty = Ui.Text(string.IsNullOrWhiteSpace(Search.Text) ? (history ? "История пока пуста" : "Здесь пока нет дел\nДобавьте первую задачу ниже") : "Ничего не найдено\nПопробуйте другой запрос или раздел", 17, "Muted");
                empty.Margin = new Thickness(18, 35, 12, 25); empty.TextWrapping = TextWrapping.Wrap; rows.Children.Add(empty);
            }
            list.ScrollToVerticalOffset(offset);
        }
        finally { rendering = false; }
    }

    private FrameworkElement TaskRow(TodoItem task)
    {
        var grid = new Grid { Margin = new Thickness(8, 9, 4, 9) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
        grid.ColumnDefinitions.Add(new ColumnDefinition()); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(32) });
        var check = Ui.Button(task.IsCompleted ? "✓" : "", task.IsCompleted ? "Вернуть задачу" : "Выполнить задачу", () => Run(() => store.Toggle(task.Id)));
        check.Width = 23; check.Height = 23; check.MinHeight = 23; check.Padding = new Thickness(0); check.FontSize = 15;
        check.VerticalAlignment = VerticalAlignment.Top; check.Margin = new Thickness(0, 4, 7, 0);
        check.SetResourceReference(BorderBrushProperty, "Muted"); grid.Children.Add(check);
        var body = new StackPanel(); Grid.SetColumn(body, 1); grid.Children.Add(body);
        if (task.IsCompleted)
        {
            var run = new Run(task.Title) { TextDecorations = TextDecorations.Strikethrough };
            var document = new FlowDocument(new Paragraph(run) { Margin = new Thickness(0) }) { PagePadding = new Thickness(2), FontSize = 17, FontFamily = FontFamily };
            var text = new RichTextBox(document) { IsReadOnly = true, IsDocumentEnabled = false, BorderThickness = new Thickness(0),
                Background = Brushes.Transparent, Padding = new Thickness(0), VerticalScrollBarVisibility = ScrollBarVisibility.Disabled };
            text.SetResourceReference(ForegroundProperty, "Muted"); Ui.Name(text, task.Title); body.Children.Add(text);
        }
        else
        {
            var editor = new TextBox { Text = drafts.GetValueOrDefault(task.Id, task.Title), AcceptsReturn = true, TextWrapping = TextWrapping.Wrap };
            Ui.Name(editor, "Текст задачи");
            void Save()
            {
                var current = store.Tasks.FirstOrDefault(t => t.Id == task.Id);
                if (current is null || editor.Text == current.Title) return;
                if (Run(() => store.Update(task.Id, t => t with { Title = editor.Text.Trim() }), refresh: false)) drafts.Remove(task.Id);
            }
            editor.TextChanged += (_, _) => drafts[task.Id] = editor.Text;
            editor.LostKeyboardFocus += (_, _) => Save();
            editor.PreviewKeyDown += (_, e) =>
            {
                if (e.Key == Key.Enter && !Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) { Save(); Composer.Focus(); e.Handled = true; }
            };
            body.Children.Add(editor);
        }
        var metadata = new WrapPanel { Margin = new Thickness(2, 5, 0, 0) };
        if (task.FlameCount > 0) { var flames = Ui.Flames(task.FlameCount); flames.Margin = new Thickness(0, 0, 8, 0); metadata.Children.Add(flames); }
        if (store.Category(task.CategoryID) is { } category)
        {
            var label = Ui.Text(category.Name, 12, "Muted"); label.Margin = new Thickness(0, 0, 10, 0); metadata.Children.Add(label);
        }
        if (task.DueDate is { } due)
        {
            var label = Ui.Text((!task.IsCompleted && due < DateTimeOffset.Now ? "Просрочено · " : "") + due.LocalDateTime.ToString("d MMM, HH:mm", CultureInfo.GetCultureInfo("ru-RU")), 12, "Muted");
            metadata.Children.Add(label);
        }
        body.Children.Add(metadata);
        var actions = Ui.Button("⋯", "Действия с задачей", () => OpenMenu(TaskMenu(task.Id), grid));
        actions.Padding = new Thickness(0); actions.VerticalAlignment = VerticalAlignment.Top; Grid.SetColumn(actions, 2); grid.Children.Add(actions);
        var background = new Border { CornerRadius = new CornerRadius(12), Child = grid };
        background.MouseEnter += (_, _) => background.SetResourceReference(Border.BackgroundProperty, "Hover");
        background.MouseLeave += (_, _) => background.Background = Brushes.Transparent;
        return background;
    }

    internal ContextMenu TaskMenu(Guid id)
    {
        var task = store.Tasks.First(t => t.Id == id);
        var menu = new ContextMenu();
        var priority = new MenuItem { Header = "Приоритет" };
        for (var index = 0; index < TaskRules.Priorities.Length; index++)
        {
            var value = TaskRules.Priorities[index];
            var item = Ui.Menu(TaskRules.PriorityNames[index], () => Run(() => store.Update(id, t => t with { Priority = value })));
            item.IsCheckable = true; item.IsChecked = task.FlameCount == index;
            if (index > 0) item.Icon = Ui.Flames(index);
            priority.Items.Add(item);
        }
        menu.Items.Add(priority);
        menu.Items.Add(Ui.Menu(task.DueDate.HasValue ? "Изменить срок…" : "Добавить срок…", () => PickDue(task.DueDate, due => Run(() => store.Update(id, t => t with { DueDate = due })))));
        if (task.DueDate.HasValue) menu.Items.Add(Ui.Menu("Убрать срок", () => Run(() => store.Update(id, t => t with { DueDate = null }))));
        var section = new MenuItem { Header = "Раздел" };
        section.Items.Add(Ui.Menu("Без раздела", () => Run(() => store.Update(id, t => t with { CategoryID = null }))));
        foreach (var category in store.Categories)
        {
            var item = Ui.Menu(category.Name, () => Run(() => store.Update(id, t => t with { CategoryID = category.Id })));
            item.IsCheckable = true; item.IsChecked = task.CategoryID == category.Id; section.Items.Add(item);
        }
        menu.Items.Add(section); menu.Items.Add(new Separator());
        menu.Items.Add(Ui.Menu("Скопировать задачу", () => Run(() => Clipboard.SetText(store.Tasks.First(t => t.Id == id).Title), false)));
        menu.Items.Add(Ui.Menu("Удалить задачу", () => Run(() => store.Delete(id))));
        return menu;
    }

    private ContextMenu CategoryMenu(Action<Guid?> select)
    {
        var menu = new ContextMenu(); menu.Items.Add(Ui.Menu("Без раздела", () => select(null)));
        foreach (var category in store.Categories) menu.Items.Add(Ui.Menu(category.Name, () => select(category.Id)));
        return menu;
    }
    private ContextMenu BuildAppMenu()
    {
        var menu = new ContextMenu();
        menu.Items.Add(Ui.Menu("Поиск задач      Ctrl+F", () => Search.Focus()));
        menu.Items.Add(Ui.Menu("Скрыть окно      Esc", Hide));
        menu.Items.Add(new Separator()); menu.Items.Add(Ui.Menu("Завершить Today", quit)); return menu;
    }
    private void TrackMenu(ContextMenu menu)
    {
        menu.Opened += (_, _) => HasOpenMenu = true;
        menu.Closed += (_, _) => HasOpenMenu = false;
    }
    private void OpenMenu(ContextMenu menu, UIElement anchor)
    {
        Interacted?.Invoke(); Ui.ApplyTheme(menu); TrackMenu(menu);
        menu.PlacementTarget = anchor; menu.Placement = PlacementMode.Bottom; menu.IsOpen = true;
    }
    private void UpdateComposer()
    {
        composeCategory.Content = store.Category(newCategory)?.Name ?? "Без раздела";
        composeDue.Content = newDue?.LocalDateTime.ToString("d MMM, HH:mm", CultureInfo.GetCultureInfo("ru-RU")) ?? "＋ Срок";
        addButton.IsEnabled = !string.IsNullOrWhiteSpace(Composer.Text);
    }
    internal void AddTask()
    {
        if (string.IsNullOrWhiteSpace(Composer.Text)) return;
        if (Run(() => store.Add(Composer.Text, newCategory, newDue)))
        {
            Composer.Clear(); newDue = null; Search.Clear(); history = false;
            selectedCategory = newCategory; Refresh(); Composer.Focus();
        }
    }
    private void AddCategory()
    {
        HasDialog = true;
        var dialog = new TextPrompt { Owner = this };
        if (dialog.ShowDialog() == true) Run(() => { var category = store.AddCategory(dialog.Value); selectedCategory = newCategory = category.Id; });
        HasDialog = false;
    }
    private void PickDue(DateTimeOffset? initial, Action<DateTimeOffset?> save)
    {
        HasDialog = true;
        var picker = new DeadlineWindow(initial) { Owner = this };
        if (picker.ShowDialog() == true) save(picker.Value);
        HasDialog = false;
    }
    internal bool Run(Action action, bool refresh = true)
    {
        try { action(); error.Visibility = Visibility.Collapsed; if (refresh) Refresh(); return true; }
        catch (Exception exception) when (exception is System.IO.IOException or UnauthorizedAccessException or ArgumentException or System.Runtime.InteropServices.ExternalException)
        { error.Text = "Не удалось сохранить изменение. " + exception.Message; error.Visibility = Visibility.Visible; return false; }
    }

    internal bool ConfirmQuit()
    {
        foreach (var id in drafts.Keys.Where(id => store.Tasks.All(t => t.Id != id)).ToList()) drafts.Remove(id);
        if (drafts.Count == 0 && string.IsNullOrWhiteSpace(Composer.Text)) return true;
        HasDialog = true;
        var discard = MessageBox.Show(this, "Есть несохранённый текст. Завершить Today и закрыть черновик?", "Today",
            MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) == MessageBoxResult.Yes;
        HasDialog = false;
        return discard;
    }
}
