"""EulaContent — shared EULA JSX.

IMPORTANT: Replace the placeholder text below with the actual agreement
from Jason's Google Doc:
https://docs.google.com/document/d/1xqEKCEVqJvdRt3NelcJvdRt3NelcJtEYISYKIdaxlvNEzELo0dZFQ/edit

Keep the outer <div className="eula-body"> wrapper so styles apply correctly.
"""

def:pub getEulaContent() -> JsxElement {
    return (
        <div className="eula-body">
            
            <p className="eula-effective">Last Updated: April 13, 2026</p>

            <p>
                PLEASE READ THIS AGREEMENT CAREFULLY BEFORE USING THIS SOFTWARE. 
                By accessing or using this software ("the Service"), you agree to be bound by the terms 
                of this End User License Agreement. If you do not agree, do not use the Service.
            </p>

            <h3>1. Educational Context</h3>
            <p>
                This software was developed by students as part of an academic course at the University 
                of Michigan. It is provided for demonstration and educational purposes only and may not 
                meet the standards of commercially released software.
            </p>

            <h3>2. Use at Your Own Risk</h3>
            <p>
                THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTY OF ANY KIND, EXPRESS 
                OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
                PARTICULAR PURPOSE, ACCURACY, RELIABILITY, OR NON-INFRINGEMENT. YOUR USE OF THE SERVICE 
                IS SOLELY AT YOUR OWN RISK.
            </p>

            <h3>3. Limitation of Liability</h3>
            <p>
                TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, NEITHER THE STUDENT DEVELOPERS, THE 
                UNIVERSITY OF MICHIGAN, ITS FACULTY, INSTRUCTORS, REGENTS, EMPLOYEES, NOR ANY AFFILIATED 
                PARTIES SHALL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR 
                EXEMPLARY DAMAGES ARISING OUT OF OR IN CONNECTION WITH YOUR USE OF — OR INABILITY TO USE — 
                THE SERVICE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. THIS INCLUDES, WITHOUT 
                LIMITATION, LOSS OF DATA, REVENUE, PROFITS, OR BUSINESS.
            </p>

            <h3>4. No Guarantees of Availability</h3>
            <p>The Service may be discontinued, modified, or taken offline at any time without notice. No 
            guarantee of uptime, continued access, or future development is made.
            </p>

            <h3>5. Data</h3>
            <p>
                Do not submit sensitive, confidential, or personal data to this Service. The student 
                developers make no guarantees regarding data security, storage, or privacy.
            </p>

            <h3>6. Indemnification</h3>
            <p>
                You agree to indemnify and hold harmless the student developers, the University of Michigan, 
                its faculty, instructors, and Regents from any claims, damages, or expenses arising from 
                your use of the Service or your violation of this Agreement.
            </p>

            <h3>7. Governing Law</h3>
            <p>
                This Agreement shall be governed by the laws of the State of Michigan, without regard to 
                conflict of law principles. Any disputes shall be subject to the exclusive jurisdiction of 
                the courts located in Washtenaw County, Michigan.
            </p>

            <h3>8. Acceptance</h3>
            <p>
                By using the Service, you acknowledge that you have read, understood, and agree to be bound 
                by this Agreement.
            </p>

            <h3>9. Contact</h3>
            <p>
                If you have any questions, please contact us at: <strong>maize.mind0@gmail.com</strong>
            </p>
        </div>
    );
}
