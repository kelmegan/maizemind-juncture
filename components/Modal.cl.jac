"""Reusable Modal component.

Props:
  - title: str                        — header text
  - content: JsxElement              — scrollable body
  - checkboxLabel: str (optional)    — if set, renders checkbox section
  - isChecked: bool                  — controlled checkbox value
  - onCheckboxChange: fn(bool)       — checkbox change handler
  - primaryButton: dict              — { label, onClick, disabled? }
  - secondaryButton: dict (optional) — { label, onClick }
  - onClose: fn (optional)           — called by X button / shroud click
  - showClose: bool (default True)   — show X button in header
  - closeable: bool (default True)   — allow closing by clicking the shroud
"""

import from "lucide-react" { X }
import from ..components.Button { Button }

def:pub Modal(props: any) -> JsxElement {
    title           = props.title           if props.title           else "";
    content         = props.content         if props.content         else None;
    checkboxLabel   = props.checkboxLabel   if props.checkboxLabel   else None;
    isChecked       = props.isChecked       if props.isChecked       else False;
    onCheckboxChange = props.onCheckboxChange if props.onCheckboxChange else None;
    primaryButton   = props.primaryButton   if props.primaryButton   else None;
    secondaryButton = props.secondaryButton if props.secondaryButton else None;
    onClose         = props.onClose         if props.onClose         else None;
    showClose       = props.showClose       if props.showClose != None else True;
    closeable       = props.closeable       if props.closeable != None else True;

    def handleShroudClick() -> None {
        if closeable and onClose { onClose(); }
    }

    def handleBoxClick(e: any) -> None {
        e.stopPropagation();
    }

    def handleCheckbox(e: any) -> None {
        if onCheckboxChange { onCheckboxChange(e.target.checked); }
    }

    primaryDisabled = primaryButton["disabled"] if primaryButton and "disabled" in primaryButton else False;

    return (
        <div className="modal-shroud" onClick={handleShroudClick}>
            <div className="modal-box" onClick={handleBoxClick}>

                <div className="modal-header">
                    <h2 className="modal-title">{title}</h2>
                    {(
                        <button className="modal-close-btn" onClick={onClose} aria-label="Close">
                            <X className="modal-close-icon" />
                        </button>
                    ) if showClose and onClose else None}
                </div>

                <div className="modal-scroll-content">
                    {content}
                </div>

                {(
                    <div className="modal-checkbox-section">
                        <label className="modal-checkbox-row">
                            <input
                                type="checkbox"
                                checked={isChecked}
                                onChange={handleCheckbox}
                                className="modal-checkbox-input"
                            />
                            <span className="modal-checkbox-label">{checkboxLabel}</span>
                        </label>
                    </div>
                ) if checkboxLabel else None}

                {(
                    <div className="modal-footer">
                        {(
                            <Button
                                label={secondaryButton["label"]}
                                onClick={secondaryButton["onClick"]}
                                variant="outline"
                            />
                        ) if secondaryButton else None}
                        {(
                            <Button
                                label={primaryButton["label"]}
                                onClick={primaryButton["onClick"]}
                                variant="primary"
                                disabled={primaryDisabled}
                                className="modal-primary-btn"
                            />
                        ) if primaryButton else None}
                    </div>
                ) if primaryButton or secondaryButton else None}

            </div>
        </div>
    );
}
