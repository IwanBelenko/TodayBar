using System;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;
using Microsoft.Win32;

namespace Today.Windows;

internal static class Ui
{
    public static bool IsDark
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        }
    }

    public static void ApplyTheme(FrameworkElement element, bool? dark = null)
    {
        var isDark = dark ?? IsDark;
        var resources = (ResourceDictionary)XamlReader.Parse("""
            <ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
              <Style TargetType="TextBlock"><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="FontSize" Value="15"/></Style>
              <Style TargetType="Button">
                <Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="Background" Value="Transparent"/>
                <Setter Property="BorderBrush" Value="Transparent"/><Setter Property="BorderThickness" Value="1"/>
                <Setter Property="FontSize" Value="15"/><Setter Property="Padding" Value="10,7"/>
                <Setter Property="Cursor" Value="Hand"/><Setter Property="MinHeight" Value="32"/>
                <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                  <Border x:Name="Box" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="12" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="Background" Value="{DynamicResource Hover}"/></Trigger>
                    <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Ink}"/></Trigger>
                    <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate></Setter.Value></Setter>
              </Style>
              <Style TargetType="TextBox">
                <Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="CaretBrush" Value="{DynamicResource Ink}"/>
                <Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
                <Setter Property="FontSize" Value="17"/><Setter Property="Padding" Value="2"/>
                <Setter Property="SelectionBrush" Value="{DynamicResource Selection}"/>
              </Style>
              <Style TargetType="ContextMenu"><Setter Property="Background" Value="{DynamicResource Raised}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="FontSize" Value="15"/></Style>
              <Style TargetType="MenuItem"><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="Padding" Value="10,6"/></Style>
              <Style TargetType="ToolTip"><Setter Property="Background" Value="{DynamicResource Raised}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/></Style>
              <Style x:Key="ScrollPage" TargetType="RepeatButton">
                <Setter Property="Focusable" Value="False"/>
                <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></Setter.Value></Setter>
              </Style>
              <Style TargetType="ScrollBar">
                <Setter Property="Width" Value="10"/><Setter Property="Background" Value="Transparent"/>
                <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
                  <Grid Background="{TemplateBinding Background}">
                    <Track x:Name="PART_Track" Orientation="{TemplateBinding Orientation}" IsDirectionReversed="True">
                      <Track.DecreaseRepeatButton><RepeatButton x:Name="Before" Command="{x:Static ScrollBar.PageUpCommand}" Style="{StaticResource ScrollPage}"/></Track.DecreaseRepeatButton>
                      <Track.Thumb><Thumb>
                        <Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="{DynamicResource Line}" CornerRadius="4" Margin="2"/></ControlTemplate></Thumb.Template>
                      </Thumb></Track.Thumb>
                      <Track.IncreaseRepeatButton><RepeatButton x:Name="After" Command="{x:Static ScrollBar.PageDownCommand}" Style="{StaticResource ScrollPage}"/></Track.IncreaseRepeatButton>
                    </Track>
                  </Grid>
                  <ControlTemplate.Triggers>
                    <Trigger Property="Orientation" Value="Horizontal">
                      <Setter Property="Width" Value="Auto"/><Setter Property="Height" Value="10"/>
                      <Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="False"/>
                      <Setter TargetName="Before" Property="Command" Value="{x:Static ScrollBar.PageLeftCommand}"/>
                      <Setter TargetName="After" Property="Command" Value="{x:Static ScrollBar.PageRightCommand}"/>
                    </Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate></Setter.Value></Setter>
              </Style>
            </ResourceDictionary>
            """);
        resources["Surface"] = Brush(isDark ? "#212121" : "#F7F7F8");
        resources["Raised"] = Brush(isDark ? "#2F2F2F" : "#FFFFFF");
        resources["Hover"] = Brush(isDark ? "#383838" : "#ECECED");
        resources["Ink"] = Brush(isDark ? "#E8E8E8" : "#292929");
        resources["Muted"] = Brush(isDark ? "#ABABAB" : "#707070");
        resources["Line"] = Brush(isDark ? "#494949" : "#DDDDDF");
        resources["Selection"] = Brush(isDark ? "#52677C" : "#BED8F1");
        if (SystemParameters.HighContrast)
        {
            resources["Surface"] = resources["Raised"] = SystemColors.WindowBrush;
            resources["Ink"] = resources["Muted"] = SystemColors.WindowTextBrush;
            resources["Line"] = SystemColors.WindowTextBrush;
            resources["Hover"] = resources["Selection"] = SystemColors.HighlightBrush;
        }
        element.Resources = resources;
    }

    public static SolidColorBrush Brush(string color) => new((Color)ColorConverter.ConvertFromString(color));
    public static void Name(DependencyObject element, string label) => AutomationProperties.SetName(element, label);
    public static TextBlock Text(string value, double size = 15, string color = "Ink")
    {
        var text = new TextBlock { Text = value, FontSize = size, VerticalAlignment = VerticalAlignment.Center };
        text.SetResourceReference(TextBlock.ForegroundProperty, color);
        return text;
    }
    public static Button Button(object title, string label, Action action)
    {
        var button = new Button { Content = title, ToolTip = label };
        Name(button, label);
        button.Click += (_, _) => action();
        return button;
    }
    public static Border Card(UIElement child, double radius = 20, string fill = "Raised")
    {
        var border = new Border { Child = child, CornerRadius = new CornerRadius(radius), BorderThickness = new Thickness(1) };
        border.SetResourceReference(Border.BackgroundProperty, fill);
        border.SetResourceReference(Border.BorderBrushProperty, "Line");
        return border;
    }
    public static Border Line() { var line = new Border { Height = 1 }; line.SetResourceReference(Border.BackgroundProperty, "Line"); return line; }
    public static MenuItem Menu(string title, Action action)
    {
        var item = new MenuItem { Header = title };
        item.Click += (_, _) => action();
        return item;
    }
    public static StackPanel Flames(int count)
    {
        var panel = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        Name(panel, $"Приоритет: {count} из 3");
        for (var index = 0; index < count; index++)
        {
            var path = new System.Windows.Shapes.Path { Width = 11, Height = 15, Stretch = Stretch.Uniform, Margin = new Thickness(0, 0, 3, 0),
                Data = Geometry.Parse("M8,0 C10,5 15,6 15,11 C15,17 1,19 1,11 C1,8 3,6 5,5 C4,9 7,9 8,6 C9,4 8,2 8,0 Z") };
            path.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, "Muted");
            panel.Children.Add(path);
        }
        return panel;
    }
}
