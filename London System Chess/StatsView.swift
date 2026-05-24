//
//  StatsView.swift
//  London System Chess
//

import SwiftUI
import SwiftData

/// The player's performance metrics over time. Not yet built — for now this
/// hosts the parked SwiftData `Item` list (add/delete) so persistence stays
/// exercised until real Stats models arrive.
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Stats Yet",
                        systemImage: AppTab.stats.systemImage,
                        description: Text("Parked Item data lives here for now.")
                    )
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            modelContext.insert(Item(timestamp: Date()))
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Item.self, inMemory: true)
}
