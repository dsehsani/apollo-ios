//
//  WinListView.swift
//  Apollo
//
//  Win List screen — PRD §04, Figma node 12839-5903.
//
//  Structure:
//    NavigationStack (.toolbar → Apollo wordmark)
//      ZStack
//        apolloBackground
//        VStack
//          WinListTabRow
//          content area (empty state / win rows)
//          WinInputField (pinned above safe area)
//        ErrorToast (overlay)
//

import SwiftUI

struct WinListView: View {
    @State private var viewModel: WinListViewModel
    /// Drives the single details sheet for both create and edit modes.
    @State private var detailsVM: WinDetailsViewModel?
    /// ID of the win that was just tapped in camera context — drives the
    /// brief filled-circle animation before the sheet dismisses.
    @State private var pendingSelectID: UUID?

    /// When provided (e.g. camera context), tapping a win name calls this
    /// and the sheet dismisses — used to set the active "Shooting for" win.
    var onSelectWin: ((WinListItem) -> Void)?

    init(
        repository: WinListRepository = MockWinListRepository(),
        onSelectWin: ((WinListItem) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: WinListViewModel(repository: repository))
        self.onSelectWin = onSelectWin
    }

    init(viewModel: WinListViewModel, onSelectWin: ((WinListItem) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectWin = onSelectWin
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    WinListTabRow(selected: viewModel.tab) { tab in
                        viewModel.switchTab(tab)
                    }

                    contentArea

                    inputArea
                }

                if let message = viewModel.transientErrorMessage {
                    ErrorToast(
                        message: message,
                        actionLabel: viewModel.phase == .error ? "Try again" : nil,
                        onAction: viewModel.phase == .error ? {
                            viewModel.clearTransientError()
                            Task { await viewModel.load() }
                        } : nil,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.clearTransientError()
                            }
                        }
                    )
                    .padding(.top, 4)
                    .zIndex(10)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("ApolloWordmark")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .accessibilityLabel("Apollo")
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .sheet(item: $detailsVM) { vm in
                WinDetailsView(viewModel: vm)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.onAppear() }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: viewModel.pendingCreateName) { _, name in
            guard let name else { return }
            openCreateSheet(name: name)
        }
    }

    // MARK: - Sheet helpers

    private func openCreateSheet(name: String) {
        let vm = viewModel.makeCreateVM(name: name)
        vm.onSave = { [weak vm] win in
            viewModel.addWin(win)
            vm?.onDismiss?()
        }
        vm.onDismiss = {
            viewModel.pendingCreateName = nil
            detailsVM = nil
        }
        detailsVM = vm
    }

    private func openEditSheet(win: WinListItem) {
        let vm = viewModel.makeEditVM(win: win)
        vm.onSave = { [weak vm] updated in
            viewModel.applyWinUpdate(updated)
            vm?.onDismiss?()
        }
        vm.onDelete = { [weak vm] in
            viewModel.removeWin(win.id)
            vm?.onDismiss?()
        }
        vm.onMarkDone = { [weak vm] updated in
            viewModel.applyWinUpdate(updated)
            reorderAfterMarkDone()
            vm?.onDismiss?()
        }
        vm.onDismiss = {
            detailsVM = nil
        }
        detailsVM = vm
    }

    private func reorderAfterMarkDone() {
        // WinListViewModel.reorderAfterToggle is private; let the next load handle it.
        // The optimistic applyWinUpdate already placed the win correctly.
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.phase {
        case .loading:
            Spacer()
        case .empty:
            emptyState
        case .loaded:
            winList
        case .error:
            emptyState
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("Your wins live here.")
                .font(.goudyItalic(18))
                .foregroundStyle(Color.apolloStroke)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Win list

    private var winList: some View {
        List {
            ForEach(viewModel.wins) { win in
                WinRowView(
                    win: win,
                    onToggleComplete: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleComplete(win)
                        }
                    },
                    onDetailsTap: { openEditSheet(win: win) },
                    onSelect: onSelectWin.map { cb in
                        {
                            guard pendingSelectID == nil else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                pendingSelectID = win.id
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 320_000_000)
                                cb(win)
                                pendingSelectID = nil
                            }
                        }
                    },
                    showAsSelected: pendingSelectID == win.id
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.apolloBackground)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for index in offsets {
                    withAnimation {
                        viewModel.deleteWin(viewModel.wins[index])
                    }
                }
            }
            .onMove { source, destination in
                viewModel.reorder(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.inactive))
    }

    // MARK: - Input field

    private var inputArea: some View {
        WinInputField(
            text: $viewModel.inputText,
            size: $viewModel.inputSize,
            onSubmit: { viewModel.submitInput() }
        )
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(Color.apolloBackground)
    }
}

// MARK: - Previews

#Preview("Empty") {
    WinListView(repository: MockWinListRepository(forceState: .empty))
}

#Preview("Loaded") {
    WinListView(repository: MockWinListRepository(forceState: .loaded))
}

#Preview("Error") {
    WinListView(repository: MockWinListRepository(forceState: .error))
}
