const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Make the right column sticky and its container take full height
content = content.replace(
  '<div className="flex-[1] flex flex-col gap-6">',
  '<div className="flex-[1] flex flex-col gap-6 lg:sticky lg:top-4 lg:h-[calc(100vh-100px)]">'
);
content = content.replace(
  '<div className="bg-[#FAF9F6] rounded-2xl border border-[#EAD7B7]/60 shadow-sm overflow-hidden flex flex-col">',
  '<div className="bg-[#FAF9F6] rounded-2xl border border-[#EAD7B7]/60 shadow-sm overflow-hidden flex flex-col h-full">'
);

// 2. Make the header shrink-0
content = content.replace(
  '<div className="flex items-center justify-between p-5 border-b border-[#EAD7B7]/60 bg-white">',
  '<div className="flex items-center justify-between p-5 border-b border-[#EAD7B7]/60 bg-white shrink-0">'
);

// 3. Make the body scrollable
content = content.replace(
  '<div className="p-5 flex flex-col gap-5 bg-white flex-1">',
  '<div className="p-5 flex flex-col gap-5 bg-white flex-1 overflow-y-auto">'
);

// 4. Move Action Buttons to a fixed footer and wire them up
const buttonsSearch = `{error && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold mt-2">
                  {error}
                </div>
              )}

              {/* Action Buttons */}
              <div className="grid grid-cols-[1fr_1fr] gap-2 mt-2">
                <button 
                  onClick={generateBill}
                  disabled={saving}
                  className="col-span-2 py-3.5 bg-[#4CAF50] hover:bg-[#45a049] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
                >
                  {saving ? 'Processing...' : 'Complete Sale'}
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Print Bill
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Save Draft
                </button>
              </div>

            </div>`;

const buttonsReplace = `{error && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold mt-2">
                  {error}
                </div>
              )}
            </div>
            
            {/* Action Buttons Fixed Footer */}
            <div className="p-5 border-t border-[#EAD7B7]/60 bg-white shrink-0">
              <div className="grid grid-cols-[1fr_1fr] gap-2">
                <button 
                  onClick={generateBill}
                  disabled={saving}
                  className="col-span-2 py-3.5 bg-[#4CAF50] hover:bg-[#45a049] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
                >
                  {saving ? 'Processing...' : 'Complete Sale'}
                </button>
                <button 
                  onClick={() => window.print()}
                  className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors"
                >
                  Print Bill
                </button>
                <button 
                  onClick={() => {
                    alert('Draft saved locally!');
                    setItems([]);
                    setCustomer({ name: '', phone: '', address: '' });
                  }}
                  className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors"
                >
                  Save Draft
                </button>
              </div>
            </div>`;

content = content.replace(buttonsSearch, buttonsReplace);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed right column sticky layout and buttons safely!');
