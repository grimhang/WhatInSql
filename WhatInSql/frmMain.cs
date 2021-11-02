using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using Microsoft.SqlServer.TransactSql.ScriptDom;

namespace WhatInSql
{
    public partial class frmMain : Form
    {
        public frmMain()
        {
            InitializeComponent();
            txtFilePath.Text = Directory.GetCurrentDirectory() + @"\SQLs\src.sql";
        }


        private void OperationSart(TextReader reader)
        {
            IList<ParseError> errors = null;

            //TextReader reader = new StreamReader(@"SQLs\src.sql");

            TSql120Parser parser = new TSql120Parser(true);
            TSqlFragment tree = parser.Parse(reader, out errors);

            foreach (ParseError err in errors)
            {
                //Console.WriteLine(err.Message);
                txtResult.Text = err.Message;
            }

            MyVisitor myVisitor = new MyVisitor();

            tree.Accept(myVisitor);

            //foreach (var tuple in myVisitor.ListIdentifier)
            //{
            //    listBoxTables.Items.Add($"{ tuple.Item1} : {tuple.Item2}");
            //}

            foreach (var tuple in myVisitor.ListIdentifier)
            {
                //txtResult.Text += $"{ tuple.Item1} : {tuple.Item2}" + Environment.NewLine;
                string tuple1 = tuple.Item1.ToString();
                string tuple2 = tuple.Item2.ToString().Replace("[", "").Replace("]", "");

                txtResult.Text += String.Format("{0,5} : {1}", tuple1, tuple2) + Environment.NewLine;
            }

            // 테이블리스트만 나열. 정렬해서
            //txtResult2.Text
            List<string> stringTableList = new List<string>();

            foreach (var tuple in myVisitor.ListIdentifier)
            {
                stringTableList.Add(tuple.Item2.ToString().Replace("[", "").Replace("]", ""));
            }

            var orderdDistinctTable = stringTableList.Distinct().OrderBy(a => a);

            foreach (var item in orderdDistinctTable)
            {
                txtResult2.Text += item + Environment.NewLine;
            }


            txtTotalCount.Text = myVisitor.ListIdentifier.Count.ToString();
            reader.Dispose();
        }


        private void btnSearchStart_Click_1(object sender, EventArgs e)
        {
            TextReader reader;

            if (tabControl1.SelectedIndex == 0)
            {
                reader = new StringReader(txtSrc.Text);
            }
            else
            {
                reader = new StreamReader(txtFilePath.Text);
            }


            OperationSart(reader);
        }
    }
}
