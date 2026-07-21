import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var store: ServerStore
    @State private var selectedID: UUID?
    @State private var isAdding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(store.servers) { server in
                    NavigationLink(value: server.id) {
                        Label(server.name, systemImage: "server.rack")
                    }
                }
                .onDelete { indexSet in indexSet.map { store.servers[$0] }.forEach(store.delete) }
            }
            .navigationTitle("RCON Servers")
            .toolbar { Button("Add server", systemImage: "plus") { isAdding = true } }
        } detail: {
            if let server = store.servers.first(where: { $0.id == selectedID }) {
                ServerDetailView(server: server)
            } else {
                ContentUnavailableView("Select a server", systemImage: "server.rack", description: Text("Add an RCON server to get started."))
            }
        }
        .sheet(isPresented: $isAdding) { ServerEditorView() }
    }
}
