# Clean Architecture and SOLID

DrawPad uses dependency direction rather than framework folders as its primary architectural rule:

1. **Domain (`Shared/Models`, `Shared/Drawing`)** contains value types and deterministic drawing rules. It imports no UI or networking framework.
2. **Application (`Shared/Protocol` and target coordinators/view models)** defines use-case messages and service boundaries.
3. **Infrastructure (`Capture`, `Video`, `Network`, `Overlay`)** implements Apple-framework adapters.
4. **Presentation (`UI`, app entry points, drawing views)** renders state and forwards user intent.

SOLID is applied pragmatically:

- **Single responsibility:** framing, coordinate mapping, stroke state, capture, encoding, transport, and rendering are separate types.
- **Open/closed:** protocol packet cases and quality profiles can be extended without changing the byte-stream parser.
- **Liskov substitution:** service protocols express observable behavior without concrete framework assumptions.
- **Interface segregation:** capture, control transport, video transport, and drawing rendering do not share a large manager interface.
- **Dependency inversion:** presentation models depend on small protocols and closures; framework adapters depend inward on shared domain messages.

UI state stays on `@MainActor`. Network/capture/video callbacks use owned serial queues and cross to the main actor only to publish state. No global mutable singleton owns application behavior; the app composition root constructs dependencies.

