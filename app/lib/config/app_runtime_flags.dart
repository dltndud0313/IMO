class AppRuntimeFlags {
  static const bool uiPreviewMode = bool.fromEnvironment(
    'IMO_UI_PREVIEW',
    defaultValue: false,
  );
}
