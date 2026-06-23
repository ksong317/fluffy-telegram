import SwiftUI

/// The signed-in home: Feed, Friends, Activity.
struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "list.bullet") }
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }
            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
    }
}
