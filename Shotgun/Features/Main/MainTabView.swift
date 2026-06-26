import SwiftUI

/// The signed-in home: Feed, Friends, Activity.
struct MainTabView: View {
    // TEMP(verify): allow launch-arg `-verifyTab N` to pick the initial tab for screenshots.
    @State private var selection = UserDefaults.standard.integer(forKey: "verifyTab")

    var body: some View {
        TabView(selection: $selection) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "list.bullet") }
                .tag(0)
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }
                .tag(1)
            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
                .tag(2)
        }
    }
}
