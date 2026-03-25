import Foundation
import DigiaExpr
@testable import DigiaEngage
import Testing
import ViewInspector
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("Widget Rendering ViewInspector")
struct WidgetRenderingViewInspectorTests {
    @Test("text style colors evaluate expressions before resolving")
    func textStyleColorExpressionsResolveAgainstScope() throws {
        let payload = RenderPayload(
            appConfigStore: AppConfigStore(),
            scopeContext: BasicExprContext(variables: ["currentItem": ["isPopular": true]])
        )

        let resolved = try #require(payload.evalColor("${if(currentItem.isPopular, '#FFFFFF', '#6B7280')}"))

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(UIColor(resolved).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(abs(red - 1) < 0.001)
        #expect(abs(green - 1) < 0.001)
        #expect(abs(blue - 1) < 0.001)
        #expect(abs(alpha - 1) < 0.001)
    }

    @Test("text widget renders resolved text")
    func textWidgetRendersResolvedText() throws {
        let widget = VWText(
            props: TextProps(
                text: .value("Hello from widget"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(
                        type: nil,
                        begin: nil,
                        end: nil,
                        colorList: [TextGradientStop(color: "#ffffff", stop: 0)]
                    )
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: "text_1"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let text = try rendered.inspect().find(ViewType.Text.self).string()

        #expect(text == "Hello from widget")
    }

    @Test("button widget renders button label")
    func buttonWidgetRendersLabel() throws {
        let widget = VWButton(
            props: ButtonProps(
                buttonState: nil,
                isDisabled: .value(false),
                disabledStyle: nil,
                defaultStyle: nil,
                text: ButtonTextProps(
                    text: .value("Tap me"),
                    textStyle: nil,
                    maxLines: nil,
                    overflow: nil
                ),
                leadingIcon: nil,
                trailingIcon: nil,
                shape: nil,
                onClick: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: "button_1"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let text = try rendered.inspect().find(ViewType.Text.self).string()

        #expect(text == "Tap me")
    }

    @Test("rich text renders simple spans as one inline text run")
    func richTextRendersSimpleInlineSpans() throws {
        let widget = VWRichText(
            props: RichTextProps(
                textSpans: [
                    RichTextSpan(
                        text: .value("Buy 1 Get 1"),
                        style: TextStyleProps(
                            fontToken: FontTokenProps(
                                value: nil,
                                font: FontDescriptorProps(
                                    fontFamily: "Poppins",
                                    weight: "bold",
                                    size: 18,
                                    height: nil,
                                    isItalic: nil,
                                    style: nil
                                )
                            ),
                            textColor: "#4B5563",
                            textBackgroundColor: nil,
                            textDecoration: nil,
                            textDecorationColor: nil,
                            gradient: nil
                        ),
                        onClick: nil
                    ),
                    RichTextSpan(
                        text: .value(" is active on\nWinter Collection Jackets."),
                        style: TextStyleProps(
                            fontToken: FontTokenProps(
                                value: nil,
                                font: FontDescriptorProps(
                                    fontFamily: "Poppins",
                                    weight: "medium",
                                    size: 18,
                                    height: nil,
                                    isItalic: nil,
                                    style: nil
                                )
                            ),
                            textColor: "#4B5563",
                            textBackgroundColor: nil,
                            textDecoration: nil,
                            textDecorationColor: nil,
                            gradient: nil
                        ),
                        onClick: nil
                    ),
                ],
                textStyle: nil,
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: "rich_text_1"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let texts = try rendered.inspect().findAll(ViewType.Text.self).map { try $0.string() }

        #expect(texts == ["Buy 1 Get 1 is active on\nWinter Collection Jackets."])
    }

    @Test("story widget renders current item and overlays")
    func storyWidgetRendersCurrentItem() throws {
        let item = VWText(
            props: TextProps(
                text: .value("Story page"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )
        let header = VWText(
            props: TextProps(
                text: .value("Header"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )

        let widget = VWStory(
            props: StoryProps(
                dataSource: nil,
                controller: nil,
                onSlideDown: nil,
                onSlideStart: nil,
                onLeftTap: nil,
                onRightTap: nil,
                onCompleted: nil,
                onPreviousCompleted: nil,
                onStoryChanged: nil,
                indicator: nil,
                initialIndex: .value(0),
                restartOnCompleted: .value(false),
                duration: .value(3000)
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: [
                "items": [item],
                "header": [header],
            ],
            parent: nil,
            refName: "story_1"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let texts = try rendered.inspect().findAll(ViewType.Text.self).map { try $0.string() }

        #expect(texts.contains("Story page"))
        #expect(texts.contains("Header"))
    }

    @Test("wrap widget renders repeated child content")
    func wrapWidgetRendersRepeatedChildContent() throws {
        let child = VWText(
            props: TextProps(
                text: .expression("${item.currentItem}"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )
        let widget = VWWrap(
            props: WrapProps(
                dataSource: .string("${state.items}"),
                spacing: .value(8),
                wrapAlignment: nil,
                wrapCrossAlignment: nil,
                direction: nil,
                runSpacing: nil,
                runAlignment: nil,
                verticalDirection: nil,
                clipBehavior: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["children": [child]],
            parent: nil,
            refName: "item"
        )

        let payload = RenderPayload(
            appConfigStore: AppConfigStore(),
            scopeContext: BasicExprContext(variables: ["state": ["items": ["One", "Two"]]])
        )

        let rendered = widget.toWidget(payload)
        let texts = try rendered.inspect().findAll(ViewType.Text.self).map { try $0.string() }

        #expect(texts.contains("One"))
        #expect(texts.contains("Two"))
    }

    #if canImport(UIKit)
    @Test("center-aligned text keeps intrinsic width without explicit sizing")
    func centeredTextDoesNotExpandToContainerWidth() {
        let text = VWText(
            props: TextProps(
                text: .value("Flash Sale"),
                textStyle: TextStyleProps(
                    fontToken: FontTokenProps(
                        value: nil,
                        font: FontDescriptorProps(
                            fontFamily: "Poppins",
                            weight: "bold",
                            size: 24,
                            height: nil,
                            isItalic: nil,
                            style: nil
                        )
                    ),
                    textColor: "#FFFFFF",
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: nil
                ),
                maxLines: nil,
                alignment: .value("center"),
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )

        let column = VWFlex(
            direction: .vertical,
            props: FlexProps(
                spacing: 0,
                startSpacing: 0,
                endSpacing: 0,
                mainAxisAlignment: "start",
                crossAxisAlignment: "center",
                mainAxisSize: "min",
                isScrollable: false,
                dataSource: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["children": [text]],
            parent: nil,
            refName: nil
        )

        let rendered = column.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 500, height: 500))

        #expect(size.width < 250)
    }
    #endif

    #if canImport(UIKit)
    @Test("horizontal scrollable row keeps the viewport width")
    func horizontalScrollableRowKeepsViewportWidth() {
        let items: [VWContainer] = (0..<3).map { _ in
            VWContainer(
                props: ContainerProps(
                    color: nil,
                    padding: nil,
                    margin: nil,
                    width: .value(120),
                    height: .value(40),
                    minWidth: nil,
                    minHeight: nil,
                    maxWidth: nil,
                    maxHeight: nil,
                    childAlignment: nil,
                    borderRadius: nil,
                    border: nil,
                    shape: nil,
                    elevation: nil,
                    shadow: nil,
                    gradiant: nil
                ),
                commonProps: nil,
                parentProps: nil,
                childGroups: nil,
                parent: nil,
                refName: nil
            )
        }

        let row = VWFlex(
            direction: .horizontal,
            props: FlexProps(
                spacing: 16,
                startSpacing: 0,
                endSpacing: 16,
                mainAxisAlignment: "start",
                crossAxisAlignment: "center",
                mainAxisSize: "max",
                isScrollable: true,
                dataSource: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["children": items],
            parent: nil,
            refName: nil
        )

        let rendered = row.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 200, height: 200))

        #expect(abs(size.width - 200) < 0.5)
        #expect(abs(size.height - 40) < 0.5)
    }

    @Test("horizontal scrollable row with min main axis shrinks to content width")
    func horizontalScrollableRowWithMinMainAxisShrinksToContent() {
        let items: [VWContainer] = (0..<2).map { _ in
            VWContainer(
                props: ContainerProps(
                    color: nil,
                    padding: nil,
                    margin: nil,
                    width: .value(120),
                    height: .value(40),
                    minWidth: nil,
                    minHeight: nil,
                    maxWidth: nil,
                    maxHeight: nil,
                    childAlignment: nil,
                    borderRadius: nil,
                    border: nil,
                    shape: nil,
                    elevation: nil,
                    shadow: nil,
                    gradiant: nil
                ),
                commonProps: nil,
                parentProps: nil,
                childGroups: nil,
                parent: nil,
                refName: nil
            )
        }

        let row = VWFlex(
            direction: .horizontal,
            props: FlexProps(
                spacing: 12,
                startSpacing: 0,
                endSpacing: 0,
                mainAxisAlignment: "spaceBetween",
                crossAxisAlignment: "center",
                mainAxisSize: "min",
                isScrollable: true,
                dataSource: nil
            ),
            commonProps: CommonProps(
                visibility: nil,
                align: nil,
                style: CommonStyle(
                    padding: .edges(left: 12, top: 12, right: 12, bottom: 12),
                    margin: nil,
                    bgColor: nil,
                    borderRadius: nil,
                    height: nil,
                    width: nil,
                    heightRaw: nil,
                    widthRaw: nil,
                    clipBehavior: nil,
                    border: nil
                ),
                onClick: nil
            ),
            parentProps: nil,
            childGroups: ["children": items],
            parent: nil,
            refName: nil
        )

        let rendered = row.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 400, height: 200))

        // Content width should stay near intrinsic width:
        // (2 * 120) + spacing(12) + padding.horizontal(24) = 276
        #expect(size.width > 250)
        #expect(size.width < 320)
        #expect(abs(size.height - 64) < 1.0)
    }

    @Test("horizontal scrollable data-driven row with min main axis keeps viewport width")
    func horizontalScrollableDataDrivenRowWithMinMainAxisKeepsViewportWidth() {
        let item = VWContainer(
            props: ContainerProps(
                color: nil,
                padding: nil,
                margin: nil,
                width: .value(120),
                height: .value(40),
                minWidth: nil,
                minHeight: nil,
                maxWidth: nil,
                maxHeight: nil,
                childAlignment: nil,
                borderRadius: nil,
                border: nil,
                shape: nil,
                elevation: nil,
                shadow: nil,
                gradiant: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: nil,
            parent: nil,
            refName: nil
        )

        let row = VWFlex(
            direction: .horizontal,
            props: FlexProps(
                spacing: 12,
                startSpacing: 0,
                endSpacing: 0,
                mainAxisAlignment: "start",
                crossAxisAlignment: "center",
                mainAxisSize: "min",
                isScrollable: true,
                dataSource: .array([.string("one"), .string("two"), .string("three")])
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["children": [item]],
            parent: nil,
            refName: nil
        )

        let rendered = row.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 400, height: 200))

        #expect(abs(size.width - 400) < 0.5)
        #expect(abs(size.height - 40) < 0.5)
    }

    @Test("stack sizes from non-positioned children only")
    func stackIgnoresPositionedChildrenForSizing() {
        let content = VWContainer(
            props: ContainerProps(
                color: nil,
                padding: nil,
                margin: nil,
                width: .value(100),
                height: .value(40),
                minWidth: nil,
                minHeight: nil,
                maxWidth: nil,
                maxHeight: nil,
                childAlignment: nil,
                borderRadius: nil,
                border: nil,
                shape: nil,
                elevation: nil,
                shadow: nil,
                gradiant: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: nil,
            parent: nil,
            refName: nil
        )

        let overlay = VWContainer(
            props: ContainerProps(
                color: nil,
                padding: nil,
                margin: nil,
                width: .value(300),
                height: .value(200),
                minWidth: nil,
                minHeight: nil,
                maxWidth: nil,
                maxHeight: nil,
                childAlignment: nil,
                borderRadius: nil,
                border: nil,
                shape: nil,
                elevation: nil,
                shadow: nil,
                gradiant: nil
            ),
            commonProps: nil,
            parentProps: ParentProps(
                position: PositionedProps(
                    top: .value(0),
                    bottom: nil,
                    left: .value(0),
                    right: nil,
                    width: nil,
                    height: nil
                ),
                expansion: nil
            ),
            childGroups: nil,
            parent: nil,
            refName: nil
        )

        let widget = VWStack(
            props: StackProps(childAlignment: "topStart", fit: "loose"),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["children": [content, overlay]],
            parent: nil,
            refName: nil
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 500, height: 500))

        #expect(abs(size.width - 100) < 0.5)
        #expect(abs(size.height - 40) < 0.5)
    }

    @Test("image with only explicit height preserves aspect ratio")
    func imageWithExplicitHeightPreservesAspectRatio() throws {
        let props = try JSONDecoder().decode(
            ImageProps.self,
            from: Data(
                """
                {
                  "src": { "imageSrc": "" },
                  "fit": "cover",
                  "aspectRatio": 0.65
                }
                """.utf8
            )
        )

        let widget = VWImage(
            props: props,
            commonProps: CommonProps(
                visibility: nil,
                align: nil,
                style: CommonStyle(
                    padding: nil,
                    margin: nil,
                    bgColor: nil,
                    borderRadius: nil,
                    height: .value(300),
                    width: nil,
                    heightRaw: "300",
                    widthRaw: nil,
                    clipBehavior: nil,
                    border: nil
                ),
                onClick: nil
            ),
            parentProps: nil,
            parent: nil,
            refName: nil
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 500, height: 500))

        #expect(abs(size.height - 300) < 0.5)
        #expect(abs(size.width - 195) < 0.5)
    }

    @Test("image uses parent container dimensions when present")
    func imageUsesParentContainerDimensionsWhenPresent() throws {
        let props = try JSONDecoder().decode(
            ImageProps.self,
            from: Data(
                """
                {
                  "src": { "imageSrc": "" },
                  "fit": "contain"
                }
                """.utf8
            )
        )

        let parentContainer = VWContainer(
            props: ContainerProps(
                color: nil,
                padding: nil,
                margin: nil,
                width: .value(40),
                height: .value(40),
                minWidth: nil,
                minHeight: nil,
                maxWidth: nil,
                maxHeight: nil,
                childAlignment: nil,
                borderRadius: nil,
                border: nil,
                shape: nil,
                elevation: nil,
                shadow: nil,
                gradiant: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: nil,
            parent: nil,
            refName: nil
        )

        let image = VWImage(
            props: props,
            commonProps: CommonProps(
                visibility: nil,
                align: nil,
                style: CommonStyle(
                    padding: nil,
                    margin: nil,
                    bgColor: nil,
                    borderRadius: nil,
                    height: .value(24),
                    width: .value(24),
                    heightRaw: "24",
                    widthRaw: "24",
                    clipBehavior: nil,
                    border: nil
                ),
                onClick: nil
            ),
            parentProps: nil,
            parent: parentContainer,
            refName: nil
        )

        let rendered = image.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let host = UIHostingController(rootView: rendered)
        let size = host.sizeThatFits(in: CGSize(width: 500, height: 500))

        #expect(abs(size.width - 40) < 0.5)
        #expect(abs(size.height - 40) < 0.5)
    }

    #endif

    @Test("timer widget renders child with initial tick value")
    func timerWidgetRendersInitialTickValue() throws {
        let child = VWText(
            props: TextProps(
                text: .expression("${tickValue}"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )
        let widget = VWTimer(
            props: TimerProps(
                controller: nil,
                duration: .value(5),
                updateInterval: .value(1),
                timerType: "countDown",
                initialValue: .value(5),
                onTick: nil,
                onTimerEnd: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: ["child": [child]],
            parent: nil,
            refName: "timer"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        let text = try rendered.inspect().find(ViewType.Text.self).string()

        #expect(text == "5")
    }

    @Test("text form field renders label hint prefix and suffix")
    func textFormFieldRendersDecorations() throws {
        let prefix = VWText(
            props: TextProps(
                text: .value("P"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )
        let suffix = VWText(
            props: TextProps(
                text: .value("S"),
                textStyle: TextStyleProps(
                    fontToken: nil,
                    textColor: nil,
                    textBackgroundColor: nil,
                    textDecoration: nil,
                    textDecorationColor: nil,
                    gradient: TextGradientProps(type: nil, begin: nil, end: nil, colorList: [TextGradientStop(color: "#ffffff", stop: 0)])
                ),
                maxLines: nil,
                alignment: nil,
                overflow: nil
            ),
            commonProps: nil,
            parentProps: nil,
            parent: nil,
            refName: nil
        )

        let widget = VWTextFormField(
            props: TextFormFieldProps(
                controller: nil,
                initialValue: nil,
                autoFocus: nil,
                enabled: .value(true),
                keyboardType: nil,
                textInputAction: nil,
                textStyle: nil,
                textAlign: nil,
                readOnly: nil,
                obscureText: nil,
                maxLines: nil,
                minLines: nil,
                maxLength: nil,
                debounceValue: nil,
                textCapitalization: nil,
                inputFormatters: nil,
                fillColor: nil,
                labelText: .value("Email"),
                labelStyle: nil,
                hintText: .value("Enter email"),
                hintStyle: nil,
                contentPadding: nil,
                focusColor: nil,
                cursorColor: nil,
                prefixIconConstraints: nil,
                suffixIconConstraints: nil,
                validationRules: nil,
                errorStyle: nil,
                enabledBorder: nil,
                disabledBorder: nil,
                focusedBorder: nil,
                focusedErrorBorder: nil,
                errorBorder: nil,
                onChanged: nil,
                onSubmit: nil
            ),
            commonProps: nil,
            parentProps: nil,
            childGroups: [
                "prefix": [prefix],
                "suffix": [suffix],
            ],
            parent: nil,
            refName: "input_1"
        )

        let rendered = widget.toWidget(RenderPayload(appConfigStore: AppConfigStore()))
        ViewHosting.host(view: rendered)
        defer { ViewHosting.expel() }
        let texts = try rendered.inspect().findAll(ViewType.Text.self).map { try $0.string() }

        #expect(texts.contains("Email"))
        #expect(texts.contains("Enter email"))
        #expect(texts.contains("P"))
        #expect(texts.contains("S"))
    }
}
