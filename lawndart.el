;;; lawndart.el --- Major mode for editing dart  -*- lexical-binding: t -*-

;; Copyright (C) 2018 Matthew Carter <m@ahungry.com>

;; Author: Matthew Carter <m@ahungry.com>
;; Maintainer: Matthew Carter <m@ahungry.com>
;; Version: 0.0.1
;; Date: 2018-02-06
;; Keywords: languages, dart

;; This file is NOT part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The dart-mode that exists doesn't properly indent, so give this a try.
;;
;; Much of this mode is derived from the js.el package.
;;
;; General Remarks:
;;
;; XXX: This mode assumes that block comments are not nested inside block
;; XXX: comments
;;
;; Exported names start with "lawndart-"; private names start with
;; "lawndart--".

;;; Code:

(require 'js)
(require 'flycheck)

(flycheck-define-checker dart
  "A Dart syntax checker using the Dart tool dartanalyzer.

See URL `http://dartlang.org/'."
  ;; :command ("dartanalyzer" "--format machine" source)
  :command ("dartanalyzer"
            "--format=machine"
            ;; (option "--format machine")
            source-inplace)
  :error-patterns
  (
   ;; INFO|HINT|UNUSED_IMPORT|/home/mcarter/src/flutter/blub_flutter/lib/main.dart|2|8|9|Unused import.
   ;; (error line-start (file-name) ":" line ": error: " (message) line-end)
   ;; (info line-start "INFO:.*?:.*?:" (file-name) ":" line ":" column ":.*?:" (message) line-end)
   (info line-start
         "INFO|"
         (one-or-more any)              ; HINT
         "|"
         (one-or-more any)              ; UNUSED_ELEMENT etc.
         "|"
         (file-name)
         "|" line "|" column "|" (one-or-more digit) "|"
         (message) line-end)
   (warning line-start
         "WARN|"
         (one-or-more any)              ; HINT
         "|"
         (one-or-more any)              ; UNUSED_ELEMENT etc.
         "|"
         (file-name)
         "|" line "|" column "|" (one-or-more digit) "|"
         (message) line-end)
   (error line-start
         "ERROR|"
         (one-or-more any)              ; HINT
         "|"
         (one-or-more any)              ; UNUSED_ELEMENT etc.
         "|"
         (file-name)
         "|" line "|" column "|" (one-or-more digit) "|"
         (message) line-end)
   )
  :modes lawndart-mode)

(add-to-list 'flycheck-checkers 'dart)

(defvar lawndart-font-lock-keywords-1
      (list
       '("%.*" . font-lock-comment-face)
       '("module \\(.+\\)\\." 1 font-lock-doc-face)
       '("@override" . font-lock-doc-face)
       '("[\t ]*\\(if\\|then\\|else\\|interface\\|pred\\|func\\|module\\|implementation\\)" . font-lock-keyword-face)
       '("[[:space:]($]\\(_*[[:upper:]]+[[:upper:][:lower:]_$0-9]*\\)" 1 font-lock-type-face)
       '("[[:space:]$]_*[[:upper:]]+[[:upper:][:lower:]_$0-9]*" . font-lock-function-name-face)
       '("\\([[:lower:]_$0-9]*?\\)" 1 font-lock-variable-name-face)
       '("\\([[:upper:][:lower:]_$0-9]*?\\):" 1 font-lock-negation-char-face)
       '("\\(\\w+\\)(" 1 font-lock-function-name-face)
       '("<\\(\\w+\\)>" 1 font-lock-type-face)
       ))

(defvar lawndart-font-lock-keywords
  (append
   lawndart-font-lock-keywords-1
   js--font-lock-keywords-3
   js--font-lock-keywords-1
   js--font-lock-keywords-2))

;;;###autoload
(define-derived-mode lawndart-mode js-mode "Dart"
  "Major mode for editing dart."
  :group 'js
  (setq-local indent-line-function #'js-indent-line)
  (setq-local beginning-of-defun-function #'js-beginning-of-defun)
  (setq-local end-of-defun-function #'js-end-of-defun)
  (setq-local open-paren-in-column-0-is-defun-start nil)
  (setq-local font-lock-defaults
              (list '(lawndart-font-lock-keywords)
                    nil nil nil nil
                    '(font-lock-syntactic-face-function
                      . js-font-lock-syntactic-face-function)))
  (setq-local syntax-propertize-function #'js-syntax-propertize)
  (setq-local prettify-symbols-alist js--prettify-symbols-alist)

  (setq-local parse-sexp-ignore-comments t)
  (setq-local which-func-imenu-joiner-function #'js--which-func-joiner)

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local fill-paragraph-function #'js-c-fill-paragraph)
  (setq-local normal-auto-fill-function #'js-do-auto-fill)

  ;; Parse cache
  (add-hook 'before-change-functions #'js--flush-caches t t)

  ;; Frameworks
  (js--update-quick-match-re)

  ;; Imenu
  (setq imenu-case-fold-search nil)
  (setq imenu-create-index-function #'js--imenu-create-index)

  ;; for filling, pretend we're cc-mode
  (setq c-comment-prefix-regexp "//+\\|\\**"
        c-paragraph-start "\\(@[[:alpha:]]+\\>\\|$\\)"
        c-paragraph-separate "$"
        c-block-comment-prefix "* "
        c-line-comment-starter "//"
        c-comment-start-regexp "/[*/]\\|\\s!"
        comment-start-skip "\\(//+\\|/\\*+\\)\\s *")
  (setq-local comment-line-break-function #'c-indent-new-comment-line)
  (setq-local c-block-comment-start-regexp "/\\*")
  (setq-local comment-multi-line t)

  (setq-local electric-indent-chars
	      (append "{}():;," electric-indent-chars)) ;FIXME: js2-mode adds "[]*".
  (setq-local electric-layout-rules
	      '((?\; . after) (?\{ . after) (?\} . before)))

  (let ((c-buffer-is-cc-mode t))
    ;; FIXME: These are normally set by `c-basic-common-init'.  Should
    ;; we call it instead?  (Bug#6071)
    (make-local-variable 'paragraph-start)
    (make-local-variable 'paragraph-separate)
    (make-local-variable 'paragraph-ignore-fill-prefix)
    (make-local-variable 'adaptive-fill-mode)
    (make-local-variable 'adaptive-fill-regexp)
    (c-setup-paragraph-variables))

  ;; Important to fontify the whole buffer syntactically! If we don't,
  ;; then we might have regular expression literals that aren't marked
  ;; as strings, which will screw up parse-partial-sexp, scan-lists,
  ;; etc. and produce maddening "unbalanced parenthesis" errors.
  ;; When we attempt to find the error and scroll to the portion of
  ;; the buffer containing the problem, JIT-lock will apply the
  ;; correct syntax to the regular expression literal and the problem
  ;; will mysteriously disappear.
  ;; FIXME: We should instead do this fontification lazily by adding
  ;; calls to syntax-propertize wherever it's really needed.
  ;;(syntax-propertize (point-max))
  )

;;;###autoload (defalias 'javascript-mode 'js-mode)

(eval-after-load 'folding
  '(when (fboundp 'folding-add-to-marks-list)
     (folding-add-to-marks-list 'lawndart-mode "// {{{" "// }}}" )))

;;;###autoload
(dolist (name (list "dart"))
  (add-to-list 'interpreter-mode-alist (cons (purecopy name) 'lawndart-mode)))

(provide 'lawndart)

;;; lawndart.el ends here
