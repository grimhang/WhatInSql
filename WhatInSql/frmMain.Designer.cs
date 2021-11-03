
namespace WhatInSql
{
    partial class frmMain
    {
        /// <summary>
        /// 필수 디자이너 변수입니다.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 사용 중인 모든 리소스를 정리합니다.
        /// </summary>
        /// <param name="disposing">관리되는 리소스를 삭제해야 하면 true이고, 그렇지 않으면 false입니다.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form 디자이너에서 생성한 코드

        /// <summary>
        /// 디자이너 지원에 필요한 메서드입니다. 
        /// 이 메서드의 내용을 코드 편집기로 수정하지 마세요.
        /// </summary>
        private void InitializeComponent()
        {
            this.txtFilePath = new System.Windows.Forms.TextBox();
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.tabFromSrc = new System.Windows.Forms.TabPage();
            this.txtSrc = new System.Windows.Forms.RichTextBox();
            this.tabPage2 = new System.Windows.Forms.TabPage();
            this.txtResult = new System.Windows.Forms.TextBox();
            this.btnSearchStart = new System.Windows.Forms.Button();
            this.txtTotalCount = new System.Windows.Forms.TextBox();
            this.label3 = new System.Windows.Forms.Label();
            this.txtResult2 = new System.Windows.Forms.TextBox();
            this.tabControl1.SuspendLayout();
            this.tabFromSrc.SuspendLayout();
            this.tabPage2.SuspendLayout();
            this.SuspendLayout();
            // 
            // txtFilePath
            // 
            this.txtFilePath.Enabled = false;
            this.txtFilePath.Location = new System.Drawing.Point(24, 30);
            this.txtFilePath.Name = "txtFilePath";
            this.txtFilePath.Size = new System.Drawing.Size(532, 21);
            this.txtFilePath.TabIndex = 1;
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabFromSrc);
            this.tabControl1.Controls.Add(this.tabPage2);
            this.tabControl1.Location = new System.Drawing.Point(1, 12);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(685, 352);
            this.tabControl1.TabIndex = 4;
            // 
            // tabFromSrc
            // 
            this.tabFromSrc.Controls.Add(this.txtSrc);
            this.tabFromSrc.Location = new System.Drawing.Point(4, 22);
            this.tabFromSrc.Name = "tabFromSrc";
            this.tabFromSrc.Padding = new System.Windows.Forms.Padding(3);
            this.tabFromSrc.Size = new System.Drawing.Size(677, 326);
            this.tabFromSrc.TabIndex = 0;
            this.tabFromSrc.Text = "From text";
            this.tabFromSrc.UseVisualStyleBackColor = true;
            // 
            // txtSrc
            // 
            this.txtSrc.Location = new System.Drawing.Point(7, 6);
            this.txtSrc.Name = "txtSrc";
            this.txtSrc.Size = new System.Drawing.Size(664, 314);
            this.txtSrc.TabIndex = 1;
            this.txtSrc.Text = "";
            // 
            // tabPage2
            // 
            this.tabPage2.Controls.Add(this.txtFilePath);
            this.tabPage2.Location = new System.Drawing.Point(4, 22);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage2.Size = new System.Drawing.Size(677, 326);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "From File";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // txtResult
            // 
            this.txtResult.Font = new System.Drawing.Font("굴림체", 9F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(129)));
            this.txtResult.Location = new System.Drawing.Point(5, 423);
            this.txtResult.Multiline = true;
            this.txtResult.Name = "txtResult";
            this.txtResult.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtResult.Size = new System.Drawing.Size(681, 176);
            this.txtResult.TabIndex = 11;
            // 
            // btnSearchStart
            // 
            this.btnSearchStart.Location = new System.Drawing.Point(10, 370);
            this.btnSearchStart.Name = "btnSearchStart";
            this.btnSearchStart.Size = new System.Drawing.Size(96, 33);
            this.btnSearchStart.TabIndex = 12;
            this.btnSearchStart.Text = "찾기시작";
            this.btnSearchStart.UseVisualStyleBackColor = true;
            this.btnSearchStart.Click += new System.EventHandler(this.btnSearchStart_Click_1);
            // 
            // txtTotalCount
            // 
            this.txtTotalCount.Location = new System.Drawing.Point(133, 385);
            this.txtTotalCount.Name = "txtTotalCount";
            this.txtTotalCount.Size = new System.Drawing.Size(100, 21);
            this.txtTotalCount.TabIndex = 14;
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(131, 370);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(29, 12);
            this.label3.TabIndex = 13;
            this.label3.Text = "갯수";
            // 
            // txtResult2
            // 
            this.txtResult2.Font = new System.Drawing.Font("굴림체", 9F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(129)));
            this.txtResult2.Location = new System.Drawing.Point(5, 615);
            this.txtResult2.Multiline = true;
            this.txtResult2.Name = "txtResult2";
            this.txtResult2.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtResult2.Size = new System.Drawing.Size(681, 176);
            this.txtResult2.TabIndex = 15;
            // 
            // frmMain
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(698, 813);
            this.Controls.Add(this.txtResult2);
            this.Controls.Add(this.txtTotalCount);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.btnSearchStart);
            this.Controls.Add(this.txtResult);
            this.Controls.Add(this.tabControl1);
            this.Name = "frmMain";
            this.Text = "WhatInSql Desktop";
            this.tabControl1.ResumeLayout(false);
            this.tabFromSrc.ResumeLayout(false);
            this.tabPage2.ResumeLayout(false);
            this.tabPage2.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion
        private System.Windows.Forms.TextBox txtFilePath;
        private System.Windows.Forms.TabControl tabControl1;
        private System.Windows.Forms.TabPage tabFromSrc;
        private System.Windows.Forms.TabPage tabPage2;
        private System.Windows.Forms.TextBox txtResult;
        private System.Windows.Forms.Button btnSearchStart;
        private System.Windows.Forms.TextBox txtTotalCount;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.RichTextBox txtSrc;
        private System.Windows.Forms.TextBox txtResult2;
    }
}

