import SwiftUI

// MARK: - App Theme
// Forest Green + Warm Amber: Stability, Growth, Effectiveness

struct AppTheme {
    // MARK: - Primary Colors
    static let forestGreen = Color(red: 0.13, green: 0.37, blue: 0.25)      // #21604A - Deep forest green
    static let forestGreenLight = Color(red: 0.18, green: 0.47, blue: 0.34) // #2E7857 - Lighter forest
    static let forestGreenDark = Color(red: 0.08, green: 0.25, blue: 0.17)  // #14402B - Darker forest
    
    // MARK: - Accent Colors
    static let amber = Color(red: 0.85, green: 0.65, blue: 0.25)            // #D9A640 - Warm amber/gold
    static let amberLight = Color(red: 0.95, green: 0.78, blue: 0.40)       // #F2C766 - Light amber
    static let amberDark = Color(red: 0.70, green: 0.50, blue: 0.15)        // #B38026 - Dark amber
    
    // MARK: - Semantic Colors
    static let success = Color(red: 0.20, green: 0.65, blue: 0.40)          // #33A666 - Success green
    static let warning = Color(red: 0.95, green: 0.75, blue: 0.30)          // #F2BF4D - Warning yellow
    static let error = Color(red: 0.85, green: 0.30, blue: 0.30)            // #D94D4D - Error red
    
    // MARK: - Neutral Colors
    static let cream = Color(red: 0.95, green: 0.93, blue: 0.88)            // Muted cream for dark mode
    static let stone = Color(red: 0.60, green: 0.58, blue: 0.55)            // Lighter stone for dark mode
    static let charcoal = Color(red: 0.12, green: 0.12, blue: 0.12)         // Deep black
    
    // MARK: - Gold Accent
    static let gold = Color(red: 0.85, green: 0.70, blue: 0.35)             // #D9B359 - Rich gold
    static let goldLight = Color(red: 0.95, green: 0.82, blue: 0.50)        // Light gold
    
    // MARK: - Background Colors (Dark Mode)
    static let backgroundPrimary = Color(red: 0.08, green: 0.08, blue: 0.08)   // Near black
    static let backgroundSecondary = Color(red: 0.12, green: 0.12, blue: 0.12) // Slightly lighter black
    static let backgroundCard = Color(red: 0.15, green: 0.15, blue: 0.14)      // Dark card background
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.75, green: 0.75, blue: 0.73)
    
    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [forestGreen, forestGreenLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [amber, amberLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let heroGradient = LinearGradient(
        colors: [forestGreenDark, forestGreen, forestGreenLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Shadows
    static let cardShadow = Color.black.opacity(0.08)
    static let elevatedShadow = Color.black.opacity(0.12)
    
    // MARK: - Typography Styles
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .rounded)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(isDisabled ? AppTheme.stone : AppTheme.forestGreen)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.forestGreen)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .stroke(AppTheme.forestGreen, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.charcoal)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(AppTheme.amber)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card View Modifier

struct ThemedCard: ViewModifier {
    var padding: CGFloat = AppTheme.Spacing.md
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.backgroundCard)
            .cornerRadius(AppTheme.Radius.lg)
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func themedCard(padding: CGFloat = AppTheme.Spacing.md) -> some View {
        modifier(ThemedCard(padding: padding))
    }
}

// MARK: - Navigation Bar Appearance

extension View {
    func applyThemeNavigationBar() -> some View {
        self.onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.forestGreen)
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 34, weight: .bold)
            ]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().tintColor = .white
        }
    }
}
