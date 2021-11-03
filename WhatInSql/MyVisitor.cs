using System;
using System.Collections.Generic;
using Microsoft.SqlServer.TransactSql.ScriptDom;

namespace WhatInSql
{
    class MyVisitor : TSqlConcreteFragmentVisitor
    {
        public List<Tuple<int, string>> ListIdentifier { get; set; } = new List<Tuple<int, string>>();
        private List<string> OnlyIdentifier { get; set; } = new List<string>();

        public override void ExplicitVisit(ExecuteStatement node)
        {
            //Console.WriteLine((node.ExecuteSpecification.ExecutableEntity as ExecutableProcedureReference).ProcedureReference.ProcedureReference.Name.BaseIdentifier.Value);
            string tempTxt = "";
            string str2char = "";

            for (int i = 0; i < node.ScriptTokenStream.Count; i++)
            {
                if (node.ScriptTokenStream[i].TokenType == TSqlTokenType.QuotedIdentifier
                    || node.ScriptTokenStream[i].TokenType == TSqlTokenType.Identifier)
                {
                    tempTxt = node.ScriptTokenStream[i].Text;

                    //if (tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "D"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "H"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "S"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "T"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "C"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "F"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "X"
                    //        )



                    if (tempTxt.Replace("[", "").Length > 1)
                    {
                        str2char = tempTxt.Replace("[", "").Substring(0, 2).ToUpper();

                        if (str2char == "DM"
                            || str2char == "HI"
                            || str2char == "SC"
                            || str2char == "SS"
                            || str2char == "TB"

                            //|| str2char == "CO"
                            || str2char == "FN"
                            || str2char == "FP"
                            || str2char == "TH"
                            || str2char == "XI"
                            )
                        {
                            if (OnlyIdentifier.FindIndex(x => x == node.ScriptTokenStream[i].Text) < 0)
                            {
                                OnlyIdentifier.Add(node.ScriptTokenStream[i].Text);
                                ListIdentifier.Add(new Tuple<int, string>(node.ScriptTokenStream[i].Line, node.ScriptTokenStream[i].Text));
                            }


                        }
                    }

                    //if (tempTxt != "NVARCHAR"
                    //    && tempTxt != "MAX"
                    //    && tempTxt != "CHAR"
                    //    && tempTxt != "INT"
                    //    && tempTxt != "VARCHAR"
                    //    && tempTxt != "NOCOUNT"
                    //    && tempTxt != "LEVEL"
                    //    && tempTxt != "ISOLATION"
                    //    && tempTxt != "UNCOMMITTED"
                    //    && tempTxt != "DATEADD"
                    //    && tempTxt != "MM")
                    //{

                    //}                    
                }
            }


            base.ExplicitVisit(node);
        }

        public override void ExplicitVisit(CreateViewStatement node)
        {
            //Console.WriteLine((node.ExecuteSpecification.ExecutableEntity as ExecutableProcedureReference).ProcedureReference.ProcedureReference.Name.BaseIdentifier.Value);
            string tempTxt = "";
            string str2char = "";

            for (int i = 0; i < node.ScriptTokenStream.Count; i++)
            {
                if (node.ScriptTokenStream[i].TokenType == TSqlTokenType.QuotedIdentifier
                    || node.ScriptTokenStream[i].TokenType == TSqlTokenType.Identifier)
                {
                    tempTxt = node.ScriptTokenStream[i].Text;

                    //if (tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "D"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "H"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "S"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "T"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "C"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "F"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "X"
                    //        )



                    if (tempTxt.Replace("[", "").Length > 1)
                    {
                        str2char = tempTxt.Replace("[", "").Substring(0, 2).ToUpper();

                        if (str2char == "DM"
                            || str2char == "HI"
                            || str2char == "SC"
                            || str2char == "SS"
                            || str2char == "TB"

                            //|| str2char == "CO"
                            || str2char == "FN"
                            || str2char == "FP"
                            || str2char == "TH"
                            || str2char == "XI"
                            )
                        {
                            if (OnlyIdentifier.FindIndex(x => x == node.ScriptTokenStream[i].Text) < 0)
                            {
                                OnlyIdentifier.Add(node.ScriptTokenStream[i].Text);
                                ListIdentifier.Add(new Tuple<int, string>(node.ScriptTokenStream[i].Line, node.ScriptTokenStream[i].Text));
                            }


                        }
                    }

                    //if (tempTxt != "NVARCHAR"
                    //    && tempTxt != "MAX"
                    //    && tempTxt != "CHAR"
                    //    && tempTxt != "INT"
                    //    && tempTxt != "VARCHAR"
                    //    && tempTxt != "NOCOUNT"
                    //    && tempTxt != "LEVEL"
                    //    && tempTxt != "ISOLATION"
                    //    && tempTxt != "UNCOMMITTED"
                    //    && tempTxt != "DATEADD"
                    //    && tempTxt != "MM")
                    //{

                    //}                    
                }
            }


            base.ExplicitVisit(node);
        }

        public override void ExplicitVisit(CreateFunctionStatement node)
        {
            //Console.WriteLine((node.ExecuteSpecification.ExecutableEntity as ExecutableProcedureReference).ProcedureReference.ProcedureReference.Name.BaseIdentifier.Value);
            string tempTxt = "";
            string str2char = "";

            for (int i = 0; i < node.ScriptTokenStream.Count; i++)
            {
                if (node.ScriptTokenStream[i].TokenType == TSqlTokenType.QuotedIdentifier
                    || node.ScriptTokenStream[i].TokenType == TSqlTokenType.Identifier)
                {
                    tempTxt = node.ScriptTokenStream[i].Text;

                    //if (tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "D"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "H"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "S"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "T"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "C"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "F"
                    //        && tempTxt.Replace("[", "").Substring(0, 1).ToUpper() == "X"
                    //        )



                    if (tempTxt.Replace("[", "").Length > 1)
                    {
                        str2char = tempTxt.Replace("[", "").Substring(0, 2).ToUpper();

                        if (str2char == "DM"
                            || str2char == "HI"
                            || str2char == "SC"
                            || str2char == "SS"
                            || str2char == "TB"

                            //|| str2char == "CO"
                            || str2char == "FN"
                            || str2char == "FP"
                            || str2char == "TH"
                            || str2char == "XI"
                            )
                        {
                            if (OnlyIdentifier.FindIndex(x => x == node.ScriptTokenStream[i].Text) < 0)
                            {
                                OnlyIdentifier.Add(node.ScriptTokenStream[i].Text);
                                ListIdentifier.Add(new Tuple<int, string>(node.ScriptTokenStream[i].Line, node.ScriptTokenStream[i].Text));
                            }


                        }
                    }

                    //if (tempTxt != "NVARCHAR"
                    //    && tempTxt != "MAX"
                    //    && tempTxt != "CHAR"
                    //    && tempTxt != "INT"
                    //    && tempTxt != "VARCHAR"
                    //    && tempTxt != "NOCOUNT"
                    //    && tempTxt != "LEVEL"
                    //    && tempTxt != "ISOLATION"
                    //    && tempTxt != "UNCOMMITTED"
                    //    && tempTxt != "DATEADD"
                    //    && tempTxt != "MM")
                    //{

                    //}                    
                }
            }


            base.ExplicitVisit(node);
        }
    }
}
