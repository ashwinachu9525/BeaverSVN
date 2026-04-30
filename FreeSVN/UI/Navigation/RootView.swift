import SwiftUI


struct RootView: View {

    @EnvironmentObject var appModel: AppModel

    var body: some View {

        NavigationSplitView {

            SidebarView()
                .frame(minWidth:300)
                .background(.ultraThinMaterial)

        } detail: {

            Group {

                if appModel.selectedRepo != nil {

                    RepoDetailView(repo:$appModel.selectedRepo)

                } else {

                    VStack(spacing:20){

                        Image(systemName:"externaldrive.badge.plus")
                            .font(.system(size:60))
                            .foregroundStyle(.secondary)

                        Text("No Repository Selected")
                            .font(.title2.weight(.semibold))

                        Text("Select or add a repository from the sidebar")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(.regularMaterial)
        .overlay {
            GuidedOnboardingOverlay()
        }
    }
}
