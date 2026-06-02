import Combine
import SwiftUI
import UIKit

@MainActor
final class DigiaTextEditingController: ObservableObject {
    @Published var text: String

    init(text: String = "") {
        self.text = text
    }
}

@MainActor
final class VWTextFormField: VirtualStatelessWidget<TextFormFieldProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let controller = payload.evalAny(props.controller) as? DigiaTextEditingController
        let obscureText = payload.eval(props.obscureText) ?? false
        let maxLines = obscureText ? 1 : (payload.eval(props.maxLines) ?? 1)
        let minLines = obscureText ? 1 : (payload.eval(props.minLines) ?? 1)
        let resolvedTextStyle = ResolvedTextStyle(payload: payload, textStyle: props.textStyle, fallbackColor: .primary)
        let resolvedLabelStyle = ResolvedTextStyle(payload: payload, textStyle: props.labelStyle, fallbackColor: .secondary)
        let resolvedHintStyle = ResolvedTextStyle(payload: payload, textStyle: props.hintStyle, fallbackColor: .secondary)
        let resolvedErrorStyle = ResolvedTextStyle(payload: payload, textStyle: props.errorStyle, fallbackColor: .red)
        let prefixConstraints = ResolvedTextFieldIconConstraints(payload: payload, props: props.prefixIconConstraints)
        let suffixConstraints = ResolvedTextFieldIconConstraints(payload: payload, props: props.suffixIconConstraints)
        let validations = (props.validationRules ?? []).map {
            ResolvedTextFieldValidationRule(
                type: $0.type ?? "",
                errorMessage: payload.eval($0.errorMessage) ?? "",
                data: TextFieldValidationData.resolve(from: payload.evalAny($0.data))
            )
        }

        return AnyView(
            DigiaTextFormFieldView(
                controller: controller,
                initialValue: payload.eval(props.initialValue),
                autoFocus: payload.eval(props.autoFocus) ?? false,
                enabled: payload.eval(props.enabled) ?? true,
                keyboardType: payload.eval(props.keyboardType),
                textInputAction: payload.eval(props.textInputAction),
                textAlign: payload.eval(props.textAlign),
                readOnly: payload.eval(props.readOnly) ?? false,
                obscureText: obscureText,
                maxLines: maxLines,
                minLines: minLines,
                maxLength: payload.eval(props.maxLength),
                textCapitalization: payload.eval(props.textCapitalization),
                inputFormatters: props.inputFormatters ?? [],
                fillColor: payload.evalColor(props.fillColor),
                labelText: payload.eval(props.labelText),
                labelStyle: resolvedLabelStyle,
                hintText: payload.eval(props.hintText),
                hintStyle: resolvedHintStyle,
                contentPadding: props.contentPadding?.edgeInsets,
                focusColor: payload.evalColor(props.focusColor),
                cursorColor: payload.evalColor(props.cursorColor),
                prefixConstraints: prefixConstraints,
                suffixConstraints: suffixConstraints,
                validations: validations,
                errorStyle: resolvedErrorStyle,
                enabledBorder: ResolvedTextFieldBorder(payload: payload, props: props.enabledBorder),
                disabledBorder: ResolvedTextFieldBorder(payload: payload, props: props.disabledBorder),
                focusedBorder: ResolvedTextFieldBorder(payload: payload, props: props.focusedBorder),
                focusedErrorBorder: ResolvedTextFieldBorder(payload: payload, props: props.focusedErrorBorder),
                errorBorder: ResolvedTextFieldBorder(payload: payload, props: props.errorBorder),
                textStyle: resolvedTextStyle,
                prefix: childOf("prefix")?.toWidget(payload),
                suffix: childOf("suffix")?.toWidget(payload),
                onChanged: props.onChanged?.isEmpty == false ? { text in
                    payload.executeAction(
                        self.props.onChanged,
                        triggerType: "onChanged",
                        scopeContext: BasicExprContext(variables: ["text": text])
                    )
                } : nil,
                onSubmit: props.onSubmit?.isEmpty == false ? { text in
                    payload.executeAction(
                        self.props.onSubmit,
                        triggerType: "onSubmit",
                        scopeContext: BasicExprContext(variables: ["text": text])
                    )
                } : nil,
                debounceMillis: payload.eval(props.debounceValue)
            )
        )
    }
}

private struct DigiaTextFormFieldView: View {
    let controller: DigiaTextEditingController?
    let initialValue: String?
    let autoFocus: Bool
    let enabled: Bool
    let keyboardType: String?
    let textInputAction: String?
    let textAlign: String?
    let readOnly: Bool
    let obscureText: Bool
    let maxLines: Int
    let minLines: Int
    let maxLength: Int?
    let textCapitalization: String?
    let inputFormatters: [TextInputFormatterRule]
    let fillColor: Color?
    let labelText: String?
    let labelStyle: ResolvedTextStyle
    let hintText: String?
    let hintStyle: ResolvedTextStyle
    let contentPadding: EdgeInsets?
    let focusColor: Color?
    let cursorColor: Color?
    let prefixConstraints: ResolvedTextFieldIconConstraints
    let suffixConstraints: ResolvedTextFieldIconConstraints
    let validations: [ResolvedTextFieldValidationRule]
    let errorStyle: ResolvedTextStyle
    let enabledBorder: ResolvedTextFieldBorder?
    let disabledBorder: ResolvedTextFieldBorder?
    let focusedBorder: ResolvedTextFieldBorder?
    let focusedErrorBorder: ResolvedTextFieldBorder?
    let errorBorder: ResolvedTextFieldBorder?
    let textStyle: ResolvedTextStyle
    let prefix: AnyView?
    let suffix: AnyView?
    let onChanged: ((String) -> Void)?
    let onSubmit: ((String) -> Void)?
    let debounceMillis: Int?

    @StateObject private var model: DigiaTextFormFieldModel

    init(
        controller: DigiaTextEditingController?,
        initialValue: String?,
        autoFocus: Bool,
        enabled: Bool,
        keyboardType: String?,
        textInputAction: String?,
        textAlign: String?,
        readOnly: Bool,
        obscureText: Bool,
        maxLines: Int,
        minLines: Int,
        maxLength: Int?,
        textCapitalization: String?,
        inputFormatters: [TextInputFormatterRule],
        fillColor: Color?,
        labelText: String?,
        labelStyle: ResolvedTextStyle,
        hintText: String?,
        hintStyle: ResolvedTextStyle,
        contentPadding: EdgeInsets?,
        focusColor: Color?,
        cursorColor: Color?,
        prefixConstraints: ResolvedTextFieldIconConstraints,
        suffixConstraints: ResolvedTextFieldIconConstraints,
        validations: [ResolvedTextFieldValidationRule],
        errorStyle: ResolvedTextStyle,
        enabledBorder: ResolvedTextFieldBorder?,
        disabledBorder: ResolvedTextFieldBorder?,
        focusedBorder: ResolvedTextFieldBorder?,
        focusedErrorBorder: ResolvedTextFieldBorder?,
        errorBorder: ResolvedTextFieldBorder?,
        textStyle: ResolvedTextStyle,
        prefix: AnyView?,
        suffix: AnyView?,
        onChanged: ((String) -> Void)?,
        onSubmit: ((String) -> Void)?,
        debounceMillis: Int?
    ) {
        self.controller = controller
        self.initialValue = initialValue
        self.autoFocus = autoFocus
        self.enabled = enabled
        self.keyboardType = keyboardType
        self.textInputAction = textInputAction
        self.textAlign = textAlign
        self.readOnly = readOnly
        self.obscureText = obscureText
        self.maxLines = maxLines
        self.minLines = minLines
        self.maxLength = maxLength
        self.textCapitalization = textCapitalization
        self.inputFormatters = inputFormatters
        self.fillColor = fillColor
        self.labelText = labelText
        self.labelStyle = labelStyle
        self.hintText = hintText
        self.hintStyle = hintStyle
        self.contentPadding = contentPadding
        self.focusColor = focusColor
        self.cursorColor = cursorColor
        self.prefixConstraints = prefixConstraints
        self.suffixConstraints = suffixConstraints
        self.validations = validations
        self.errorStyle = errorStyle
        self.enabledBorder = enabledBorder
        self.disabledBorder = disabledBorder
        self.focusedBorder = focusedBorder
        self.focusedErrorBorder = focusedErrorBorder
        self.errorBorder = errorBorder
        self.textStyle = textStyle
        self.prefix = prefix
        self.suffix = suffix
        self.onChanged = onChanged
        self.onSubmit = onSubmit
        self.debounceMillis = debounceMillis
        _model = StateObject(wrappedValue: DigiaTextFormFieldModel(
            controller: controller,
            initialValue: initialValue,
            validations: validations,
            debounceMillis: debounceMillis,
            onChanged: onChanged,
            onSubmit: onSubmit
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let labelText, !labelText.isEmpty {
                textLine(labelText, style: labelStyle)
            }

            ZStack(alignment: placeholderAlignment) {
                fieldBackground

                HStack(spacing: 0) {
                    if let prefix {
                        prefix
                            .frame(
                                minWidth: prefixConstraints.minWidth,
                                idealWidth: prefixConstraints.maxWidth,
                                maxWidth: prefixConstraints.maxWidth,
                                minHeight: prefixConstraints.minHeight,
                                idealHeight: prefixConstraints.maxHeight,
                                maxHeight: prefixConstraints.maxHeight
                            )
                    }

                    ZStack(alignment: placeholderAlignment) {
                        HStack(spacing: 0) {
                            fieldInput

                            if let suffix {
                                suffix
                                    .frame(
                                        minWidth: suffixConstraints.minWidth,
                                        idealWidth: suffixConstraints.maxWidth,
                                        maxWidth: suffixConstraints.maxWidth,
                                        minHeight: suffixConstraints.minHeight,
                                        idealHeight: suffixConstraints.maxHeight,
                                        maxHeight: suffixConstraints.maxHeight
                                    )
                            }
                        }
                        .padding(resolvedContentPadding)

                        if model.text.isEmpty, let hintText, !hintText.isEmpty {
                            textLine(hintText, style: hintStyle)
                                .padding(resolvedContentPadding)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }

            if let validationError = model.validationError, !validationError.isEmpty {
                textLine(validationError, style: errorStyle)
            }
        }
    }

    @ViewBuilder
    private var fieldBackground: some View {
        if let activeBorder = selectedBorder {
            DigiaTextFieldBorderShape(border: activeBorder)
                .fill(fillColor ?? .clear)
                .overlay {
                    DigiaTextFieldBorderShape(border: activeBorder)
                        .stroke(activeBorder.color, style: activeBorder.strokeStyle)
                }
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fillColor ?? .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            model.isFocused ? (focusColor ?? .clear) : .clear,
                            lineWidth: model.isFocused ? 1 : 0
                        )
                }
        }
    }

    private var fieldInput: some View {
        Group {
            DigiaPlatformTextInput(
                text: $model.text,
                isFocused: $model.isFocused,
                configuration: platformConfiguration,
                onUserInput: model.handleUserInput(_:),
                onSubmit: model.submitCurrentText
            )
        }
        .frame(maxWidth: .infinity, alignment: alignmentFrame)
    }

    private var platformConfiguration: DigiaTextInputConfiguration {
        DigiaTextInputConfiguration(
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscureText,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textAlignment: textAlign,
            textCapitalization: textCapitalization,
            cursorColor: cursorColor,
            textStyle: textStyle,
            inputFormatters: inputFormatters,
            autoFocus: autoFocus
        )
    }

    private var selectedBorder: ResolvedTextFieldBorder? {
        if !enabled {
            return disabledBorder ?? enabledBorder
        }
        if model.validationError != nil {
            return model.isFocused ? (focusedErrorBorder ?? errorBorder ?? focusedBorder ?? enabledBorder) : (errorBorder ?? enabledBorder)
        }
        if model.isFocused {
            return focusedBorder ?? enabledBorder ?? focusColor.map { ResolvedTextFieldBorder.defaultOutline(color: $0) }
        }
        return enabledBorder
    }

    private var resolvedContentPadding: EdgeInsets {
        if max(minLines, maxLines) > 1 {
            return contentPadding ?? EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        }
        return contentPadding ?? EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    }

    private var placeholderAlignment: Alignment {
        switch textAlign {
        case "right", "end":
            return .trailing
        case "center":
            return .center
        default:
            return .leading
        }
    }

    private var alignmentFrame: Alignment {
        switch textAlign {
        case "right", "end":
            return .trailing
        case "center":
            return .center
        default:
            return .leading
        }
    }

    private func textLine(_ value: String, style: ResolvedTextStyle) -> some View {
        Text(value)
            .font(style.font)
            .foregroundStyle(style.color)
    }
}

@MainActor
private final class DigiaTextFormFieldModel: ObservableObject {
    @Published var text: String
    @Published var validationError: String?
    @Published var isFocused = false

    private let controller: DigiaTextEditingController?
    private let validations: [ResolvedTextFieldValidationRule]
    private let onChanged: ((String) -> Void)?
    private let onSubmit: ((String) -> Void)?
    private let debouncer: Debouncer?
    private var cancellable: AnyCancellable?

    init(
        controller: DigiaTextEditingController?,
        initialValue: String?,
        validations: [ResolvedTextFieldValidationRule],
        debounceMillis: Int?,
        onChanged: ((String) -> Void)?,
        onSubmit: ((String) -> Void)?
    ) {
        self.controller = controller
        self.validations = validations
        self.onChanged = onChanged
        self.onSubmit = onSubmit
        if let controller {
            text = controller.text
        } else {
            text = initialValue ?? ""
        }
        if let debounceMillis, debounceMillis > 0 {
            debouncer = Debouncer(delay: .milliseconds(debounceMillis))
        } else {
            debouncer = nil
        }
        validate(text)

        cancellable = controller?.$text
            .removeDuplicates()
            .sink { [weak self] nextValue in
                guard let self else { return }
                guard self.text != nextValue else { return }
                self.text = nextValue
                self.validate(nextValue)
            }
    }

    func handleUserInput(_ nextValue: String) {
        text = nextValue
        if controller?.text != nextValue {
            controller?.text = nextValue
        }
        validate(nextValue)
        if let debouncer {
            debouncer.run { [onChanged] in
                onChanged?(nextValue)
            }
        } else {
            onChanged?(nextValue)
        }
    }

    func submitCurrentText() {
        onSubmit?(text)
    }

    private func validate(_ value: String) {
        validationError = validations.first { rule in
            switch rule.type {
            case "required":
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case "minLength":
                if case let .int(limit) = rule.data {
                    return value.count < limit
                }
                return false
            case "maxLength":
                if case let .int(limit) = rule.data {
                    return value.count > limit
                }
                return false
            case "pattern":
                if case let .string(pattern) = rule.data {
                    guard !value.isEmpty else { return false }
                    return value.range(of: pattern, options: .regularExpression) == nil
                }
                return false
            default:
                return false
            }
        }?.errorMessage
    }
}

@MainActor
private struct ResolvedTextStyle {
    let font: Font
    let color: Color
    let uiFont: UIFont

    init(payload: RenderPayload, textStyle: TextStyleProps?, fallbackColor: Color) {
        font = payload.resources.font(textStyle: textStyle)
        color = payload.evalColor(textStyle?.textColor) ?? fallbackColor
        uiFont = payload.resources.uiFont(textStyle: textStyle)
    }
}

@MainActor
private struct ResolvedTextFieldIconConstraints {
    let minWidth: CGFloat
    let minHeight: CGFloat
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    init(payload: RenderPayload, props: TextFieldIconConstraints?) {
        minWidth = CGFloat(payload.eval(props?.minWidth) ?? 0)
        minHeight = CGFloat(payload.eval(props?.minHeight) ?? 0)
        maxWidth = CGFloat(payload.eval(props?.maxWidth) ?? 48)
        maxHeight = CGFloat(payload.eval(props?.maxHeight) ?? 48)
    }
}

private enum TextFieldValidationData: Equatable {
    case int(Int)
    case string(String)
    case none

    static func resolve(from value: Any?) -> TextFieldValidationData {
        switch value {
        case let value as Int:
            return .int(value)
        case let value as Double:
            return .int(Int(value))
        case let value as String:
            return .string(value)
        default:
            return .none
        }
    }
}

private struct ResolvedTextFieldValidationRule: Equatable {
    let type: String
    let errorMessage: String
    let data: TextFieldValidationData
}

@MainActor
private struct ResolvedTextFieldBorder {
    enum Kind {
        case outline
        case underline
    }

    let kind: Kind
    let color: Color
    let lineWidth: CGFloat
    let dashPattern: [CGFloat]
    let cornerRadius: CornerRadiusProps

    var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, dash: dashPattern)
    }

    init?(payload: RenderPayload, props: TextFieldBorderProps?) {
        guard let props else { return nil }
        let kindValue = props.borderType?.value ?? "outlineInputBorder"
        switch kindValue {
        case "underlineInputBorder", "underlineDashedInputBorder":
            kind = .underline
        case "outlineInputBorder", "outlineDashedInputBorder":
            kind = .outline
        default:
            return nil
        }
        // Match Flutter's default `BorderSide.none` when values are omitted.
        color = payload.evalColor(props.borderColor) ?? .clear
        lineWidth = CGFloat(payload.eval(props.borderWidth) ?? 0)
        let isDashed = kindValue == "outlineDashedInputBorder" || kindValue == "underlineDashedInputBorder"
        dashPattern = isDashed ? (props.borderType?.dashPattern ?? [3, 3]).map { CGFloat($0) } : []
        cornerRadius = props.borderRadius ?? CornerRadiusProps(topLeft: 8, topRight: 8, bottomRight: 8, bottomLeft: 8)
    }

    static func defaultOutline(color: Color) -> ResolvedTextFieldBorder {
        ResolvedTextFieldBorder(
            kind: .outline,
            color: color,
            lineWidth: 1,
            dashPattern: [],
            cornerRadius: CornerRadiusProps(topLeft: 8, topRight: 8, bottomRight: 8, bottomLeft: 8)
        )
    }

    private init(kind: Kind, color: Color, lineWidth: CGFloat, dashPattern: [CGFloat], cornerRadius: CornerRadiusProps) {
        self.kind = kind
        self.color = color
        self.lineWidth = lineWidth
        self.dashPattern = dashPattern
        self.cornerRadius = cornerRadius
    }
}

private struct DigiaTextFieldBorderShape: Shape {
    let border: ResolvedTextFieldBorder

    func path(in rect: CGRect) -> Path {
        switch border.kind {
        case .outline:
            return DigiaRoundedRect(cornerRadius: border.cornerRadius).path(in: rect)
        case .underline:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }
}


private struct DigiaTextInputConfiguration {
    let enabled: Bool
    let readOnly: Bool
    let obscureText: Bool
    let maxLines: Int
    let minLines: Int
    let maxLength: Int?
    let keyboardType: String?
    let textInputAction: String?
    let textAlignment: String?
    let textCapitalization: String?
    let cursorColor: Color?
    let textStyle: ResolvedTextStyle
    let inputFormatters: [TextInputFormatterRule]
    let autoFocus: Bool

    func filteredText(from candidate: String) -> String {
        var output = candidate
        for formatter in inputFormatters {
            guard let regex = formatter.regex else { continue }
            output = applyFormatter(type: formatter.type, regex: regex, to: output)
        }
        if let maxLength, output.count > maxLength {
            output = String(output.prefix(maxLength))
        }
        return output
    }

    private func applyFormatter(type: String?, regex: String, to input: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: regex) else {
            return input
        }
        let characters = input.map(String.init)
        let filtered = characters.filter { character in
            let range = NSRange(location: 0, length: character.utf16.count)
            let matches = expression.firstMatch(in: character, range: range) != nil
            switch type {
            case "allow":
                return matches
            case "deny":
                return !matches
            default:
                return true
            }
        }
        return filtered.joined()
    }
}

private struct DigiaPlatformTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let configuration: DigiaTextInputConfiguration
    let onUserInput: (String) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.containerTapped))
        tap.cancelsTouchesInView = false
        container.addGestureRecognizer(tap)

        let inputView: UIView
        if configuration.maxLines > 1 {
            let textView = UITextView()
            textView.delegate = context.coordinator
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            inputView = textView
            context.coordinator.textView = textView
        } else {
            let textField = UITextField()
            textField.delegate = context.coordinator
            textField.borderStyle = .none
            textField.backgroundColor = .clear
            textField.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
            inputView = textField
            context.coordinator.textField = textField
        }
        inputView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inputView)
        NSLayoutConstraint.activate([
            inputView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            inputView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            inputView.topAnchor.constraint(equalTo: container.topAnchor),
            inputView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self

        if let textField = context.coordinator.textField {
            if textField.text != text {
                textField.text = text
            }
            apply(to: textField)
            syncFirstResponder(for: textField, in: uiView, coordinator: context.coordinator)
        }

        if let textView = context.coordinator.textView {
            if textView.text != text {
                textView.text = text
            }
            apply(to: textView)
            syncFirstResponder(for: textView, in: uiView, coordinator: context.coordinator)
        }
    }

    private func syncFirstResponder(for view: UIView, in uiView: UIView, coordinator: Coordinator) {
        guard uiView.window != nil else { return }

        if configuration.autoFocus, !coordinator.didRequestFocus {
            coordinator.didRequestFocus = true
            Task { @MainActor in
                _ = view.becomeFirstResponder()
            }
            return
        }

        // Keep UIKit focus state consistent so tapping another field works reliably.
        if isFocused, !view.isFirstResponder {
            Task { @MainActor in
                _ = view.becomeFirstResponder()
            }
        } else if !isFocused, view.isFirstResponder {
            Task { @MainActor in
                _ = view.resignFirstResponder()
            }
        }
    }

    private func apply(to textField: UITextField) {
        textField.isEnabled = configuration.enabled
        textField.isSecureTextEntry = configuration.obscureText
        textField.keyboardType = keyboardType(configuration.keyboardType)
        textField.returnKeyType = returnKeyType(configuration.textInputAction)
        textField.autocapitalizationType = capitalization(configuration.textCapitalization)
        textField.textAlignment = textAlignment(configuration.textAlignment)
        textField.font = configuration.textStyle.uiFont
        textField.textColor = UIColor(configuration.textStyle.color)
        textField.tintColor = UIColor(configuration.cursorColor ?? .accentColor)
    }

    private func apply(to textView: UITextView) {
        textView.isEditable = configuration.enabled && !configuration.readOnly
        textView.isSelectable = configuration.enabled
        textView.keyboardType = keyboardType(configuration.keyboardType)
        textView.returnKeyType = returnKeyType(configuration.textInputAction)
        textView.autocapitalizationType = capitalization(configuration.textCapitalization)
        textView.textAlignment = textAlignment(configuration.textAlignment)
        textView.font = configuration.textStyle.uiFont
        textView.textColor = UIColor(configuration.textStyle.color)
        textView.tintColor = UIColor(configuration.cursorColor ?? .accentColor)
    }

    private func keyboardType(_ value: String?) -> UIKeyboardType {
        switch value {
        case "multiline":
            return .default
        case "number":
            return .numberPad
        case "phone":
            return .phonePad
        case "datetime":
            return .numbersAndPunctuation
        case "emailAddress":
            return .emailAddress
        case "url":
            return .URL
        case "visiblePassword":
            return .asciiCapable
        case "name":
            return .namePhonePad
        case "streetAddress":
            return .default
        case "none":
            return .default
        default:
            return .default
        }
    }

    private func returnKeyType(_ value: String?) -> UIReturnKeyType {
        switch value {
        case "go":
            return .go
        case "search":
            return .search
        case "send":
            return .send
        case "next":
            return .next
        case "done":
            return .done
        case "continueAction":
            return .continue
        case "join":
            return .join
        case "route":
            return .route
        case "emergencyCall":
            return .emergencyCall
        default:
            return .default
        }
    }

    private func capitalization(_ value: String?) -> UITextAutocapitalizationType {
        switch value {
        case "words":
            return .words
        case "sentences":
            return .sentences
        case "characters":
            return .allCharacters
        default:
            return .none
        }
    }

    private func textAlignment(_ value: String?) -> NSTextAlignment {
        switch value {
        case "right", "end":
            return .right
        case "center":
            return .center
        case "justify":
            return .justified
        default:
            return .left
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate, UITextViewDelegate {
        var parent: DigiaPlatformTextInput
        weak var textField: UITextField?
        weak var textView: UITextView?
        var didRequestFocus = false

        init(parent: DigiaPlatformTextInput) {
            self.parent = parent
        }

        @objc
        func containerTapped() {
            if let textField {
                _ = textField.becomeFirstResponder()
            } else if let textView {
                _ = textView.becomeFirstResponder()
            }
        }

        @objc
        func editingChanged(_ sender: UITextField) {
            let filtered = parent.configuration.filteredText(from: sender.text ?? "")
            if sender.text != filtered {
                sender.text = filtered
            }
            parent.text = filtered
            parent.onUserInput(filtered)
        }

        func textFieldDidBeginEditing(_: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_: UITextField) {
            parent.isFocused = false
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !parent.configuration.readOnly else { return false }
            let currentValue = textField.text ?? ""
            let candidate = (currentValue as NSString).replacingCharacters(in: range, with: string)
            let filtered = parent.configuration.filteredText(from: candidate)
            if filtered != candidate {
                textField.text = filtered
                parent.text = filtered
                parent.onUserInput(filtered)
                return false
            }
            return true
        }

        func textViewDidBeginEditing(_: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_: UITextView) {
            parent.isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            let filtered = parent.configuration.filteredText(from: textView.text)
            if textView.text != filtered {
                textView.text = filtered
            }
            parent.text = filtered
            parent.onUserInput(filtered)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !parent.configuration.readOnly else { return false }
            let currentValue = textView.text ?? ""
            let candidate = (currentValue as NSString).replacingCharacters(in: range, with: text)
            let filtered = parent.configuration.filteredText(from: candidate)
            if filtered != candidate {
                textView.text = filtered
                parent.text = filtered
                parent.onUserInput(filtered)
                return false
            }
            return true
        }
    }
}
