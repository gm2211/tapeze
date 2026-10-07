import UIKit
import SwiftUI
import Combine

class KeyboardViewController: UIInputViewController {

    private var keyboardState = KeyboardState()
    private var hostingController: UIHostingController<KeyboardContainerView>?
    private var heightConstraint: NSLayoutConstraint?
    private var heightCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTransparentBackgrounds()

        updateLandscapeState()
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardState.effectiveKeyboardHeight)
        // The system installs its own default-height constraint on the input
        // view. At `.defaultHigh` ours lost the first layout pass, so the
        // keyboard came up at the system height and only grew afterwards - by
        // which point the host had already scrolled the focused field to sit
        // just above a much shorter keyboard, leaving it covered.
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint

        // Publish the height before the first appearance so the very first
        // keyboard frame the host is notified about already carries our size.
        preferredContentSize = CGSize(width: 0, height: keyboardState.effectiveKeyboardHeight)

        let keyboardView = KeyboardContainerView(
            state: keyboardState,
            onCharacter: { [weak self] char in
                self?.textDocumentProxy.insertText(char)
                self?.scheduleInputContextUpdate()
            },
            onBackspace: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
                self?.scheduleInputContextUpdate()
            },
            onDeleteWord: { [weak self] in
                self?.deletePreviousWord()
                self?.scheduleInputContextUpdate()
            },
            onDeleteLine: { [weak self] in
                self?.deleteCurrentLineBeforeCursor()
                self?.scheduleInputContextUpdate()
            },
            onEnter: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
                self?.scheduleInputContextUpdate()
            },
            onMoveCursor: { [weak self] offset in
                self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
                self?.scheduleInputContextUpdate()
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.view.isOpaque = false

        addChild(hc)
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController = hc
        bindKeyboardHeight()
        updateInputContext()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureTransparentBackgrounds()
        keyboardState.reloadPersistedAppearanceSettings()
        updateLandscapeState()
        applyKeyboardHeight(keyboardState.effectiveKeyboardHeight, animated: false, force: true)
        updateInputContext()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reassertKeyboardHeightIfNeeded()
    }

    private func configureTransparentBackgrounds() {
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        inputView?.isOpaque = false
        // Without self-sizing the input view keeps the system height and our
        // constraint never reaches the host as a keyboard frame change.
        inputView?.allowsSelfSizing = true
    }

    /// The system can still lay us out at its own height on the first
    /// presentation, and the host sizes its insets from that frame. Re-assert
    /// once we are on screen so a corrective frame change reaches the host
    /// while the field is still focused, instead of only on the next focus.
    private func reassertKeyboardHeightIfNeeded() {
        let desired = keyboardState.effectiveKeyboardHeight
        guard abs(view.bounds.height - desired) > 0.5 else { return }

        heightConstraint?.constant = desired
        preferredContentSize = CGSize(width: 0, height: desired)
        view.superview?.setNeedsLayout()
        view.setNeedsLayout()
        view.superview?.layoutIfNeeded()
        view.layoutIfNeeded()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateLandscapeState()
        applyKeyboardHeight(keyboardState.effectiveKeyboardHeight, animated: false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateLandscapeState()
            self.applyKeyboardHeight(self.keyboardState.effectiveKeyboardHeight, animated: false)
        })
    }

    /// Share of the screen's short side the keyboard may use in landscape.
    /// The saved height (default 360pt) is tuned for portrait; on a ~390pt
    /// landscape screen it would leave almost nothing of the text visible.
    private static let landscapeHeightShare: CGFloat = 0.58

    /// Switches the split layout on in landscape and caps its height.
    private func updateLandscapeState() {
        let screenBounds = view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
        let isLandscape = screenBounds.width > screenBounds.height
            || traitCollection.verticalSizeClass == .compact
        let cap: CGFloat? = isLandscape
            ? (min(screenBounds.width, screenBounds.height) * Self.landscapeHeightShare).rounded()
            : nil
        if keyboardState.landscapeMaxHeight != cap {
            keyboardState.landscapeMaxHeight = cap
        }
    }

    private func bindKeyboardHeight() {
        heightCancellable = keyboardState.$keyboardHeight
            .combineLatest(keyboardState.$landscapeMaxHeight)
            .map { height, cap in cap.map { min(height, $0) } ?? height }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] height in
                self?.applyKeyboardHeight(height, animated: true)
            }
    }

    private func applyKeyboardHeight(_ height: CGFloat, animated: Bool, force: Bool = false) {
        // The constraint constant already matches on a fresh launch because it is
        // created from the persisted height, so it cannot be the only thing we
        // check: preferredContentSize is what actually sizes the input view, and
        // skipping it here left every reopened keyboard at the system height.
        // `force` covers a controller that is reused across appearances: the
        // stored values already match, but the input view still needs the
        // layout pass that makes the height stick for this presentation.
        guard force || heightConstraint?.constant != height || preferredContentSize.height != height else { return }

        heightConstraint?.constant = height
        preferredContentSize = CGSize(width: 0, height: height)

        let updates = {
            self.view.superview?.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: updates)
        } else {
            updates()
        }
    }

    private func deletePreviousWord() {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        let characters = Array(context)
        var index = characters.count
        var deleteCount = 0

        while index > 0, characters[index - 1].isWhitespace, characters[index - 1] != "\n" {
            index -= 1
            deleteCount += 1
        }

        while index > 0, !characters[index - 1].isWhitespace {
            index -= 1
            deleteCount += 1
        }

        deleteBackward(times: max(deleteCount, 1))
    }

    private func deleteCurrentLineBeforeCursor() {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        var deleteCount = 0
        for character in context.reversed() {
            if character == "\n" { break }
            deleteCount += 1
        }

        deleteBackward(times: max(deleteCount, 1))
    }

    private func deleteBackward(times count: Int) {
        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {
        updateInputContext()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateInputContext()
    }

    private func updateInputContext() {
        switch textDocumentProxy.keyboardType {
        case .URL, .webSearch:
            keyboardState.isURLField = true
        default:
            keyboardState.isURLField = false
        }

        keyboardState.autocapitalizationMode = Self.autocapitalizationMode(
            for: textDocumentProxy.autocapitalizationType
        )
        keyboardState.updateAutocapitalization(before: textDocumentProxy.documentContextBeforeInput)
    }

    /// Re-reads the document after our own edit. The keyboard clears shift
    /// synchronously once a character is inserted, which would otherwise wipe
    /// the capital `textDidChange` had just raised for the next sentence.
    private func scheduleInputContextUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateInputContext()
        }
    }

    private static func autocapitalizationMode(
        for type: UITextAutocapitalizationType?
    ) -> AutocapitalizationMode {
        // A nil trait means the host never expressed a preference, which for a
        // plain text field behaves as sentence capitalization.
        guard let type else { return .sentences }

        switch type {
        case .none:
            return .none
        case .words:
            return .words
        case .allCharacters:
            return .allCharacters
        case .sentences:
            return .sentences
        @unknown default:
            return .sentences
        }
    }
}
