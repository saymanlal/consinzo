"use client";

import React, { useEffect, useRef } from "react";
import Editor, { type Monaco, type OnMount } from "@monaco-editor/react";

export interface EditorDiagnostic {
  severity: "error" | "warning" | "info";
  file: string;
  line?: number;
  column?: number;
  message: string;
}

export interface CodeEditorProps {
  filePath: string;
  value: string;
  readOnly?: boolean;
  theme?: "vs-dark" | "vs";
  diagnostics?: EditorDiagnostic[];
  onChange?: (next: string) => void;
  onSave?: () => void;
}

export function detectMonacoLanguage(filePath: string): string {
  if (filePath.endsWith(".sol")) return "sol";
  if (filePath.endsWith(".rs")) return "rust";
  if (filePath.endsWith(".ts") || filePath.endsWith(".tsx")) return "typescript";
  if (filePath.endsWith(".js") || filePath.endsWith(".jsx")) return "javascript";
  if (filePath.endsWith(".py")) return "python";
  if (filePath.endsWith(".yaml") || filePath.endsWith(".yml")) return "yaml";
  if (filePath.endsWith(".md")) return "markdown";
  return "plaintext";
}

export function ConsinzoMonacoEditor({
  filePath,
  value,
  readOnly = false,
  theme = "vs-dark",
  diagnostics = [],
  onChange,
  onSave,
}: CodeEditorProps) {
  const editorRef = useRef<Parameters<OnMount>[0] | null>(null);
  const monacoRef = useRef<Monaco | null>(null);

  const handleMount: OnMount = (editor, monaco) => {
    editorRef.current = editor;
    monacoRef.current = monaco;

    // Register Solidity language token rules if not present
    if (!monaco.languages.getLanguages().some((l: { id: string }) => l.id === "sol")) {
      monaco.languages.register({ id: "sol" });
      monaco.languages.setMonarchTokensProvider("sol", {
        keywords: [
          "pragma", "solidity", "contract", "interface", "library", "abstract", "is",
          "import", "function", "modifier", "event", "struct", "enum", "mapping",
          "public", "external", "internal", "private", "view", "pure", "payable",
          "memory", "storage", "calldata", "returns", "return", "require", "revert",
          "if", "else", "for", "while", "unchecked", "emit", "constructor", "receive",
          "fallback", "constant", "immutable", "indexed", "virtual", "override",
        ],
        typeKeywords: [
          "address", "bool", "string", "bytes", "bytes32", "bytes4", "uint256",
          "uint128", "uint96", "uint64", "uint32", "uint8", "int256", "uint", "int",
        ],
        tokenizer: {
          root: [
            [/\/\/.*$/, "comment"],
            [/\/\*/, "comment", "@comment"],
            [/"([^"\\]|\\.)*"/, "string"],
            [/[a-zA-Z_]\w*/, {
              cases: {
                "@keywords": "keyword",
                "@typeKeywords": "type",
                "@default": "identifier",
              },
            }],
            [/0x[0-9a-fA-F]+/, "number.hex"],
            [/\d+/, "number"],
          ],
          comment: [
            [/[^/*]+/, "comment"],
            [/\*\//, "comment", "@pop"],
            [/[/*]/, "comment"],
          ],
        },
      });
    }

    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS, () => {
      onSave?.();
    });
  };

  useEffect(() => {
    const editor = editorRef.current;
    const monaco = monacoRef.current;
    if (!editor || !monaco) return;
    const model = editor.getModel();
    if (!model) return;

    const fileDiagnostics = diagnostics.filter((d) => d.file === filePath && d.line);
    const markers = fileDiagnostics.map((d) => ({
      severity:
        d.severity === "error"
          ? monaco.MarkerSeverity.Error
          : d.severity === "warning"
            ? monaco.MarkerSeverity.Warning
            : monaco.MarkerSeverity.Info,
      startLineNumber: d.line ?? 1,
      startColumn: d.column ?? 1,
      endLineNumber: d.line ?? 1,
      endColumn: (d.column ?? 1) + 12,
      message: d.message,
    }));

    monaco.editor.setModelMarkers(model, "consinzo-solc", markers);
  }, [diagnostics, filePath]);

  return (
    <div className="h-full w-full overflow-hidden">
      <Editor
        height="100%"
        path={filePath}
        language={detectMonacoLanguage(filePath)}
        value={value}
        theme={theme}
        onMount={handleMount}
        onChange={(v) => onChange?.(v ?? "")}
        options={{
          readOnly,
          fontSize: 13.5,
          fontFamily: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          automaticLayout: true,
          tabSize: 4,
          wordWrap: "off",
          renderLineHighlight: "line",
          padding: { top: 12, bottom: 12 },
        }}
      />
    </div>
  );
}
